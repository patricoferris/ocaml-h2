(*----------------------------------------------------------------------------
 *  Copyright (c) 2018 Inhabited Type LLC.
 *  Copyright (c) 2019-2020 Antonio N. Monteiro.
 *
 *  All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without
 *  modification, are permitted provided that the following conditions
 *  are met:
 *
 *  1. Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer.
 *
 *  2. Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution.
 *
 *  3. Neither the name of the author nor the names of his contributors
 *     may be used to endorse or promote products derived from this software
 *     without specific prior written permission.
 *
 *  THIS SOFTWARE IS PROVIDED BY THE CONTRIBUTORS ``AS IS'' AND ANY EXPRESS
 *  OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 *  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 *  DISCLAIMED.  IN NO EVENT SHALL THE AUTHORS OR CONTRIBUTORS BE LIABLE FOR
 *  ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 *  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 *  OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 *  HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 *  STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
 *  ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *  POSSIBILITY OF SUCH DAMAGE.
 *---------------------------------------------------------------------------*)

open Async
open Dream_h2

module Server = struct
  let create_connection_handler
      ?(config = Dream_h2.Config.default)
      ~request_handler
      ~error_handler
      client_addr
      socket
    =
    let connection =
      Dream_h2.Server_connection.create
        ~config
        ~error_handler:(error_handler client_addr)
        (request_handler client_addr)
    in
    Dream_gluten_async.Server.create_connection_handler
      ~read_buffer_size:config.read_buffer_size
      ~protocol:(module Dream_h2.Server_connection)
      connection
      client_addr
      socket

  module SSL = struct
    let create_connection_handler
        ?(config = Dream_h2.Config.default)
        ~request_handler
        ~error_handler
        client_addr
        socket
      =
      let connection =
        Dream_h2.Server_connection.create
          ~config
          ~error_handler:(error_handler client_addr)
          (request_handler client_addr)
      in
      Dream_gluten_async.Server.SSL.create_connection_handler
        ~read_buffer_size:config.read_buffer_size
        ~protocol:(module Dream_h2.Server_connection)
        connection
        client_addr
        socket

    let create_connection_handler_with_default
        ~certfile ~keyfile ?config ~request_handler ~error_handler
      =
      let make_ssl_server =
        Dream_gluten_async.Server.SSL.create_default
          ~alpn_protocols:[ "h2" ]
          ~certfile
          ~keyfile
      in
      fun client_addr socket ->
        make_ssl_server client_addr socket >>= fun ssl_server ->
        create_connection_handler
          ?config
          ~request_handler
          ~error_handler
          client_addr
          ssl_server
  end
end

module Client = struct
  module Client_runtime = Dream_gluten_async.Client

  type socket = Client_runtime.socket

  type runtime = Client_runtime.t

  type t =
    { connection : Client_connection.t
    ; runtime : runtime
    }

  let create_connection
      ?(config = Config.default) ?push_handler ~error_handler socket
    =
    let connection =
      Client_connection.create ~config ?push_handler ~error_handler
    in
    Client_runtime.create
      ~read_buffer_size:config.read_buffer_size
      ~protocol:(module Client_connection)
      connection
      socket
    >>| fun runtime -> { runtime; connection }

  let request t = Client_connection.request t.connection

  let ping t = Client_connection.ping t.connection

  let shutdown t = Client_runtime.shutdown t.runtime

  let is_closed t = Client_runtime.is_closed t.runtime

  module SSL = struct
    module Client_runtime = Dream_gluten_async.Client.SSL

    type socket = Client_runtime.socket

    type runtime = Client_runtime.t

    type t =
      { connection : Client_connection.t
      ; runtime : runtime
      }

    let create_connection
        ?(config = Config.default) ?push_handler ~error_handler socket
      =
      let connection =
        Client_connection.create ~config ?push_handler ~error_handler
      in
      Client_runtime.create
        ~read_buffer_size:config.read_buffer_size
        ~protocol:(module Client_connection)
        connection
        socket
      >>| fun runtime -> { runtime; connection }

    let create_connection_with_default
        ?(config = Config.default) ?push_handler ~error_handler socket
      =
      Client_runtime.create_default ~alpn_protocols:[ "http/1.1" ] socket
      >>= fun ssl_client ->
      create_connection ~config ?push_handler ~error_handler ssl_client

    let request t = Client_connection.request t.connection

    let ping t = Client_connection.ping t.connection

    let shutdown t = Client_runtime.shutdown t.runtime

    let is_closed t = Client_runtime.is_closed t.runtime
  end
end
