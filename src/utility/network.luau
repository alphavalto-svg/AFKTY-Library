--!strict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- Finds the executor's HTTP request function. Every executor exposes one under a different
-- name, so the caller gets whichever is present and nil when none is.

local network = {}
network.__index = network

export type RequestFn = (...any) -> any

-- accepts the environment table from getfenv()
function network.getRequestFn(env: any?): RequestFn?
    env = env or getfenv()
    return env.request
        or env.http_request
        or (env.http and env.http.request)
        or (env.syn and env.syn.request)
        or (env.fluxus and env.fluxus.request)
end

return network
