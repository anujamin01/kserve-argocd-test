local health_status = {}
health_status.status = "Progressing"
health_status.message = "Waiting for InferenceService to report status..."

if obj.status ~= nil then
  local progressing = false
  local degraded = false
  local stopped = false
  local status_false = 0
  local status_unknown = 0
  local msg = ""

  -- Check if intentionally scaled to zero (minReplicas = 0)
  if obj.spec ~= nil and obj.spec.predictor ~= nil then
    if obj.spec.predictor.minReplicas ~= nil and obj.spec.predictor.minReplicas == 0 then
      stopped = true
    end
  end

  if obj.status.modelStatus ~= nil then
    if obj.status.modelStatus.transitionStatus ~= "UpToDate" then
      if obj.status.modelStatus.transitionStatus == "InProgress" then
        progressing = true
      else
        degraded = true
      end
      msg = msg .. "0: transitionStatus | " .. obj.status.modelStatus.transitionStatus
    end
  end
  
  if obj.status.conditions ~= nil then
    for i, condition in pairs(obj.status.conditions) do
      -- Check for Stopped condition = True
      if condition.type == "Stopped" and condition.status == "True" then
        stopped = true
      end

      -- Skip Stopped condition for counting AND message building
      if condition.type ~= "Stopped" then
        if condition.status == "Unknown" then
          status_unknown = status_unknown + 1
        elseif condition.status == "False" then
          status_false = status_false + 1
        end

        -- Only add to message if not True AND not Stopped
        if condition.status ~= "True" then
          msg = msg .. " | " .. i .. ": " .. condition.type .. " | " .. condition.status
          if condition.reason ~= nil and condition.reason ~= "" then
            msg = msg .. " | " .. condition.reason
          end
          if condition.message ~= nil and condition.message ~= "" then
            msg = msg .. " | " .. condition.message
          end
        end
      end
    end

    -- Determine health status
    if stopped == true then
      health_status.status = "Suspended"
      health_status.message = "InferenceService is suspended (minReplicas=0 or Stopped=True)"
    elseif progressing == false and degraded == false and status_unknown == 0 and status_false == 0 then
      health_status.status = "Healthy"
      health_status.message = "InferenceService is healthy."
    elseif degraded == false and status_unknown > 0 then
      health_status.status = "Progressing"
      health_status.message = msg
    else
      health_status.status = "Degraded"
      health_status.message = msg
    end
  end
end

return health_status