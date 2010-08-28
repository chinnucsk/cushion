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
%%% @author Samuel <samuelrivas@gmail.com>
%%% @copyright (C) 2010, Samuel
%%% @doc This module contains functions that map directly to CouchDB api.
%%%
%%% See [http://wiki.apache.org/couchdb/API_Cheatsheet] for a quick reference.
%%%
%%% All functions in this module return the raw response from CouchDB.
%%%
%%% @end
%%%-------------------------------------------------------------------

%%% XXX So far, this is basically a huge copy'n paste work. After the first wave
%%% of tests are finished, this is going to be heavily refactorised

-module(cushion_couch_api).

-export([get_document/4, create_document/4, update_document/5,
	 delete_document/5, create_db/3, delete_db/3]).

%%--------------------------------------------------------------------
%% @doc Fetch a document.
%% @spec get_document(string(), integer(), string(), string()) -> binary()
%% @throws {couchdb_error, {ErrorCode::integer(), Body::binary()}}
%% @end
%%--------------------------------------------------------------------
get_document(Couch, Port, Db, DocId) ->
    {Result, Body} = request(Couch, Port, "GET", Db ++ "/" ++ DocId),
    check_result(200, Result, Body).

%%--------------------------------------------------------------------
%% @doc Create a new document with autogenerated Id.
%%
%% In general, it's better to use {@link update_document/5} to create new
%% documents. This call performs a POST call that could be problematic in
%% certain network configurations.
%%
%% @spec create_document(string(), integer(), string(),
%%                       deep_string()) -> binary()
%% @throws {couchdb_error, {ErrorCode::integer(), Body::binary()}}
%% @end
%%--------------------------------------------------------------------
create_document(Couch, Port, Db, Fields) ->
    {ok, {Result, _Headers, Body}} =
	lhttpc:request(
	  "http://" ++ Couch ++ ":" ++ integer_to_list(Port) ++ "/" ++ Db,
	  "POST", [{"Content-Type", "application/json"}], Fields, infinity),
    check_result(201, Result, Body).

%%--------------------------------------------------------------------
%% @doc Create a new document or update an existing one
%%
%% Creates a new document in the database if `DocId' doesn't already exist. If
%% it exists, then it is updated to `Fields' if, and only if, there is a `_rev'
%% field and its value is the same as the current `_rev' value of the document
%% stored in the DB.
%%
%% @spec update_document(string(), integer(), string(), string(),
%%                       deep_string()) -> binary()
%% @throws {couchdb_error, {ErrorCode::integer(), Body::binary()}}
%% @end
%%--------------------------------------------------------------------
update_document(Couch, Port, Db, DocId, Fields) ->
    {ok, {Result, _Headers, Body}} =
	lhttpc:request(
	  "http://" ++ Couch ++ ":" ++ integer_to_list(Port) ++ "/" ++ Db ++ "/"
	  ++ DocId,
	  "PUT", [], Fields, infinity),
    check_result(201, Result, Body).

%%--------------------------------------------------------------------
%% @doc Delete a document
%% @spec delete_document(string(), integer(), string(), string(), string()) ->
%%                       binary()
%% @throws {couchdb_error, {ErrorCode::integer(), Body::binary()}}
%% @end
%%--------------------------------------------------------------------
delete_document(Couch, Port, Db, DocId, Rev) ->
    {Result, Body} =
        request(Couch, Port, "DELETE", Db ++ "/" ++ DocId ++ "?rev=" ++ Rev),
    check_result(200, Result, Body).

%%--------------------------------------------------------------------
%% @doc Create a new database
%%
%% @spec create_db(string(), integer(), string()) -> binary()
%% @throws {couchdb_error, {ErrorCode::integer(), Body::binary()}}
%% @end
%%--------------------------------------------------------------------
create_db(Couch, Port, Db) ->
    {Result, Body} = request(Couch, Port, "PUT", Db),
    check_result(201, Result, Body).

%%--------------------------------------------------------------------
%% @doc Delete and existing database
%%
%% @spec delete_db(string(), integer(), string()) -> binary()
%% @throws {couchdb_error, {ErrorCode::integer(), Body::binary()}}
%% @end
%%--------------------------------------------------------------------
delete_db(Couch, Port, Db) ->
    {Result, Body} = request(Couch, Port, "DELETE", Db),
    check_result(200, Result, Body).

%%%-------------------------------------------------------------------
%%% Internals
%%%-------------------------------------------------------------------
check_result(Expected, Result, Body) ->
    case Result of
        {Expected, _} ->
            Body;
        {ErrorCode, _} ->
            couch_error(Body, ErrorCode)
    end.

couch_error(Body, ErrorCode) ->
   throw({couchdb_error, {ErrorCode, Body}}).

request(Couch, Port, Method, Path) ->
    {ok, {Result, _Headers, Body}} =
	lhttpc:request(
	  "http://" ++ Couch ++ ":" ++ integer_to_list(Port) ++ "/" ++ Path,
	  Method, [], infinity),
    {Result, Body}.
