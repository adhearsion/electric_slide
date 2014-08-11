Electric Slide - Simple Call Distribution for Adhearsion
====================================================================

This library implements a simple FIFO (First-In, First-Out) call queue for Adhearsion.

To ensure proper operation, a few things are assumed:

* Agents will only be logged into a single queue at a time
    If you have two types of agents (say "support" and "sales") then you should have two queues, each with their own pool of agents
* Agent authentication will happen before entering the queue - it is not the queue's concern
* The strategy for both agents and callers is FIFO - the first (available) of each type to begin waiting is selected
* Other (custom) strategies can be implemented by creating custom queue implementations - see below
* Queues will be implemented as a Celluloid Actor, which should protect the call selection strategies against race conditions
* When an agent is selected to take a call, the agent is called. For other behaviors, a custom queue must be implemented

TODO:
* Example for using Matrioska to offer Agents and Callers interactivity while waiting
* How to handle MOH

Example Queue
-------------

```Ruby
class SupportQueue < ElectricSlide::Queue
  name "Support Queue"

  caller_strategy :fifo
  agent_strategy  :fifo

  while_waiting_for_agent do
    # Default block to be looped on queued calls (callers) while waiting for an agent
    # May be overriden if a callback is supplied on the QueuedCall object
  end

  while_waiting_for_calls do
    # Default block to be looped on agent calls while waiting for a caller
    # May be overriden if a callback is supplied on the AgentCall object
  end
end
```


Example CallController
----------------------

```Ruby
class EnterTheQueue < Adhearsion::CallController
  def run
    answer
    SupportQueue.wait_for_agent(call) do
      # Play hold music or other features until an agent answers
      # This block should loop if necessary
      # This block overrides the `#while_waiting_for_agent` above
    end

    # Do any post-queue activity here, like possibly a satisfaction survey
    invoke CustomerSatisfactionSurvey

    say "Goodbye"
  end
end
```


Example Agent Login
-------------------

```Ruby
class WorkTheQueue < Adhearsion::CallController
  def run
    answer
    SupportQueue.work_queue(call) # Blocks while agent works the queue
    say "Thanks for working the queue. You are logged out. Goodbye."
  end
end
```


Example Agent Login with Callbacks
----------------------------------

```Ruby
class WorkTheQueueWithStyle < Adhearsion::CallController
  def run
    answer
    agent = ElectricSlide::AgentCall.new call

    agent.on_caller do
      # Optional
      # Block to execute when agent is selected to take a call
      # Occurs before the media is bridged
      # Returning false indicates that the agent cannot take this call
    end

    agent.on_hold do
      # Optional 
      # Play some audio to the agent
      # Can also be used to update external status trackers
      # Called when the agent has entered the queue and is waiting for a call
    end

    agent.on_logout do
      # Optional
      # Can be used to check external presence (like XMPP) and trigger something
      # to call the agent and add him back to the queue
      # May also be used to update stats
      # This block must assume that the call object associated with this
      # agent is already inactive (hungup)
    end

    SupportQueue.work_queue(agent) # Blocks while agent works the queue
  end
end
```


Example integrating external presence
-------------------------------------

```Ruby
Adhearsion::XMPP.register_handlers do
  client.register_handler(:presence) do |p|
    case p.state
      when :available
        agent = AgentLookup.by_jid p.from # Placeholder - replace with something that gets a voice address
        call = Adhearsion::OutboundCall.new
        call[:jid] = p.from
        call.execute_controller_or_router_on_answer WorkTheQueue
        call.dial agent

      when :unavailable
        call = Adhearsion.active_calls.values.detect do |call|
          call[:jid] == p.from
        end
        call.hangup
      end
    end
  end
end
```

