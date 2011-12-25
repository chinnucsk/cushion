%%%-------------------------------------------------------------------
%%% Copyright 2010 Samuel Rivas <samuelrivas@gmail.com>
%%%
%%% This file is part of Cushion.
%%%
%%% Cushion is free software: you can redistribute it and/or modify it under
%%% the terms of the GNU General Public License as published by the Free
%%% Software Foundation, either version 3 of the License, or (at your option)
%%% any later version.
%%%
%%% Cushion is distributed in the hope that it will be useful, but WITHOUT ANY
%%% WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
%%% FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
%%% details.
%%%
%%% You should have received a copy of the GNU General Public License along with
%%% Cushion.  If not, see <http://www.gnu.org/licenses/>.
%%%-------------------------------------------------------------------
%%%-------------------------------------------------------------------
%%% @author Samuel Rivas <samuelrivas@gmail.com>
%%% @copyright (C) 2010, Samuel Rivas
%%% @doc This module contains functions that map directly to CouchDB api.
%%%
%%% See [http://wiki.apache.org/couchdb/API_Cheatsheet] for a quick reference.
%%%
%%% All functions in this module return the raw response from CouchDB.
%%%
%%% @end
%%%-------------------------------------------------------------------
-module(cushion_couch_api).

-export([get_doc/4, create_doc/4, update_doc/5, get_dbs/2,
	 delete_doc/5, create_db/3, delete_db/3]).

%%--------------------------------------------------------------------
%% @doc Fetch a document.
%% @spec get_doc(string(), integer(), string(), string()) -> binary()
%% @throws {couchdb_error, {ErrorCode::integer(), Body::binary()}}
%% @end
%%--------------------------------------------------------------------
get_doc(Couch, Port, Db, DocId) ->
    http_request(Couch, Port, get, path(Db, DocId)).

%%--------------------------------------------------------------------
%% @doc Create a new document with autogenerated Id.
%%
%% In general, it's better to use {@link update_doc/5} to create new
%% documents. This call performs a POST call that could be problematic in
%% certain network configurations.
%%
%% @spec create_doc(string(), integer(), string(),
%%                       deep_string()) -> binary()
%% @throws {couchdb_error, {ErrorCode::integer(), Body::binary()}}
%% @end
%%--------------------------------------------------------------------
create_doc(Couch, Port, Db, Fields) ->
    http_request(Couch, Port, post, Db, Fields).

%%--------------------------------------------------------------------
%% @doc Create a new document or update an existing one
%%
%% Creates a new document in the database if `DocId' doesn't already exist. If
%% it exists, then it is updated to `Fields' if, and only if, there is a `_rev'
%% field and its value is the same as the current `_rev' value of the document
%% stored in the DB.
%%
%% @spec update_doc(string(), integer(), string(), string(),
%%                       deep_string()) -> binary()
%% @throws {couchdb_error, {ErrorCode::integer(), Body::binary()}}
%% @end
%%--------------------------------------------------------------------
update_doc(Couch, Port, Db, DocId, Fields) ->
    http_request(Couch, Port, put, path(Db, DocId), Fields).

%%--------------------------------------------------------------------
%% @doc Delete a document
%% @spec delete_doc(string(), integer(), string(), string(), string()) ->
%%                       binary()
%% @throws {couchdb_error, {ErrorCode::integer(), Body::binary()}}
%% @end
%%--------------------------------------------------------------------
delete_doc(Couch, Port, Db, DocId, Rev) ->
    http_request(Couch, Port, delete, path(Db, DocId, Rev)).

%%--------------------------------------------------------------------
%% @doc Get available databases
%%
%% @spec get_dbs(string(), integer()) -> binary()
%% @throws {couchdb_error, {ErrorCode::integer(), Body::binary()}}
%% @end
%%--------------------------------------------------------------------
get_dbs(Couch, Port) ->
    http_request(Couch, Port, get, "_all_dbs").

%%--------------------------------------------------------------------
%% @doc Create a new database
%%
%% @spec create_db(string(), integer(), string()) -> binary()
%% @throws {couchdb_error, {ErrorCode::integer(), Body::binary()}}
%% @end
%%--------------------------------------------------------------------
create_db(Couch, Port, Db) ->
    http_request(Couch, Port, put, Db).

%%--------------------------------------------------------------------
%% @doc Delete and existing database
%%
%% @spec delete_db(string(), integer(), string()) -> binary()
%% @throws {couchdb_error, {ErrorCode::integer(), Body::binary()}}
%% @end
%%--------------------------------------------------------------------
delete_db(Couch, Port, Db) ->
    http_request(Couch, Port, delete, Db).

%%%-------------------------------------------------------------------
%%% Internals
%%%-------------------------------------------------------------------
http_request(Couch, Port, Method, Path) ->
    http_request(Couch, Port, Method, Path, "").

http_request(Couch, Port, Method, Path, Payload) ->
    {Status, Body} = send_request(Couch, Port, Method, Path, Payload),
    check_status(Method, Status, Body).

send_request(Couch, Port, Method, Path, Payload) ->
    Url = cushion_util:format("http://~s:~w/~s", [Couch, Port, Path]),
    Request = make_request(Url, Method, Payload),
    {ok, {{_, Status, Reason}, _, Body}} =
        httpc:request(Method, Request, [{timeout, infinity}], []),
    {{Status, Reason}, Body}.

make_request(Url, Method, Payload)
  when Method =:= put; Method =:= post ->
    {Url, [], "application/json", list_to_binary(Payload)};
make_request(Url, _, _) ->
    {Url, []}.

check_status(Method, Status, Body) ->
    Expected = expected_status(Method),
    case Status of
        {Expected, _} ->
            Body;
        {ErrorCode, _} ->
            couch_error(ErrorCode, Body)
    end.

expected_status(Method) when Method =:= get; Method =:= delete ->
    200;
expected_status(Method) when Method =:= put; Method =:= post ->
    201.

couch_error(ErrorCode, Body) ->
   throw({couchdb_error, {ErrorCode, Body}}).

path(Db, File) ->
    filename:join(Db, File).

path(Db, File, Rev) ->
    io_lib:format("~s?rev=~s", [path(Db, File), Rev]).
