%%
%%   Copyright 2015 Zalando SE
%%
%%   Licensed under the Apache License, Version 2.0 (the "License");
%%   you may not use this file except in compliance with the License.
%%   You may obtain a copy of the License at
%%
%%       http://www.apache.org/licenses/LICENSE-2.0
%%
%%   Unless required by applicable law or agreed to in writing, software
%%   distributed under the License is distributed on an "AS IS" BASIS,
%%   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%%   See the License for the specific language governing permissions and
%%   limitations under the License.
%%
%% @doc
%%   load scenario controller
-module(typhoon_scenario).
-behaviour(pipe).
-author('dmitry.kolesnikov@zalando.fi').

-export([
   start_link/3
  ,init/1
  ,free/2
  ,ioctl/2
  ,handle/3
]).
%% ambit callback
-export([
   process/1,
   handoff/2
]).

%%%----------------------------------------------------------------------------   
%%%
%%% Factory
%%%
%%%----------------------------------------------------------------------------   

start_link(Vnode, Name, Spec) ->
   pipe:start_link(?MODULE, [Vnode, Name, Spec], []).

init([Vnode, Name, Spec]) ->
   % erlang:send(self(), tick),
   {ok, handle, 
      #{
         vnode => Vnode,
         name  => Name,
         spec  => Spec
         % fd    => pipe:ioctl(typhoon_peer, fd)
      }
   }.

free(_, _) ->
   ok.

ioctl(_, _) ->
   throw(not_implemented).

%%%----------------------------------------------------------------------------   
%%%
%%% ambit
%%%
%%%----------------------------------------------------------------------------   

process(Root) ->
   {ok, Root}.

handoff(Root, Vnode) ->
   pipe:call(Root, {handoff, Vnode}).

%%%----------------------------------------------------------------------------   
%%%
%%% pipe
%%%
%%%----------------------------------------------------------------------------   

handle({handoff, _Vnode}, Tx, State) ->
   pipe:ack(Tx, ok),
   {next_state, handle, State};

handle(run, Tx, #{spec := Spec}=State) ->
   %% @todo: non-blocking spawn
   pipe:ack(Tx, 
      run(pair:x(<<"n">>, Spec), q:new([erlang:node() | erlang:nodes()]), State)
   ),
   {next_state, handle, State};
   
handle(_Msg, _Tx, State) ->
   {next_state, handle, State}.

%%%----------------------------------------------------------------------------   
%%%
%%% private
%%%
%%%----------------------------------------------------------------------------   

%%
%% run test case on cluster
run(0, _Nodes, _State) ->
   ok;
run(N,  Nodes, #{name :=Name, spec := Spec}=State) ->
   %% @todo: manage status of unit processes (use pts ?) 
   supervisor:start_child({typhoon_unit_sup, q:head(Nodes)}, [Name, Spec]),
   run(N - 1, q:enq(q:head(Nodes), q:tail(Nodes)), State).




