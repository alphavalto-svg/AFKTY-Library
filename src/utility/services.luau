--!strict

-- Copyright (c) 2026 Corridon Capital
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

-- GetService through cloneref where the executor provides it. A cloned reference cannot be
-- traced back to this script by a game hooking the service, so every service goes through here.

local services = {}

function services.getService(name)
    local service = game:GetService(name)
    return if cloneref then cloneref(service) else service
end

return services
