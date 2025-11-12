hs = {}
hs.status = "Progressing"
hs.message = "Waiting for InferenceService to report status..."

if obj.status ~= nil then
  local progressing = false
  local degraded = false
  local stopped = false
  local status_false = 0
  local status_unknown = 0
  local msg = ""
  local counter = 1  -- Start at 1 by default
  
  -- Check if minReplicas is 0 (suspended)
  if obj.spec ~= nil and obj.spec.predictor ~= nil then
    if obj.spec.predictor.minReplicas ~= nil and obj.spec.predictor.minReplicas == 0 then
      stopped = true
    end
  end
  
  -- Check model transition status
  if obj.status.modelStatus ~= nil and obj.status.modelStatus.transitionStatus ~= nil then
    if obj.status.modelStatus.transitionStatus ~= "UpToDate" then
      if obj.status.modelStatus.transitionStatus == "InProgress" then
        progressing = true
      else
        degraded = true
      end
      msg = "0: transitionStatus | " .. obj.status.modelStatus.transitionStatus
      counter = 1  -- Reset to 1 after adding transitionStatus at index 0
    end
  end
  
  -- Check conditions
  if obj.status.conditions ~= nil then
    for i, condition in pairs(obj.status.conditions) do
      -- Check for explicit Stopped=True condition
      if condition.type == "Stopped" and condition.status == "True" then
        stopped = true
      end
      
      -- Count ALL non-Stopped conditions for indexing
      if condition.type ~= "Stopped" then
        if condition.status == "Unknown" then
          msg = msg .. " | " .. tostring(counter) .. ": " .. condition.type .. " | " .. condition.status
          if condition.reason ~= nil then
            msg = msg .. " | " .. condition.reason
          end
          if condition.message ~= nil and condition.message ~= "" then
            msg = msg .. " | " .. condition.message
          end
          status_unknown = status_unknown + 1
        elseif condition.status == "False" then
          msg = msg .. " | " .. tostring(counter) .. ": " .. condition.type .. " | " .. condition.status
          if condition.reason ~= nil then
            msg = msg .. " | " .. condition.reason
          end
          if condition.message ~= nil and condition.message ~= "" then
            msg = msg .. " | " .. condition.message
          end
          status_false = status_false + 1
        end
        -- Increment counter for ALL non-Stopped conditions
        counter = counter + 1
      end
    end
  end
  
  -- Determine final health status
  if stopped == true then
    hs.status = "Suspended"
    hs.message = "InferenceService is suspended (minReplicas=0 or Stopped=True)"
  elseif progressing == true then
    hs.status = "Progressing"
    hs.message = msg
  elseif degraded == true then
    hs.status = "Degraded"
    hs.message = msg
  elseif status_unknown > 0 and status_false == 0 then
    hs.status = "Progressing"
    hs.message = msg
  elseif status_false > 0 then
    hs.status = "Degraded"
    hs.message = msg
  else
    hs.status = "Healthy"
    hs.message = "InferenceService is healthy."
  end
end

return hs
