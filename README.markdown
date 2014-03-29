Electric Slide - Automatic Call Distribution (ACD) Services for Adhearsion
====================================================================

This library makes a few assumptions:

* Individual queues will be declared by creating a class that inherits from ElectricSlide::Queue
* Agents will only be logged into a single queue at a time
* Agent authentication will happen before entering the queue - it is not the queue's concern
* If you have two types of agents (say "support" and "sales") then you should have two queues, each with their own pool of agents
* The default strategy for both agents and callers is FIFO - the first to begin waiting is the first to be connected
* Other (custom) strategies can be implemented by setting `agent_strategy` or `caller_strategy` - see `ElectricSlide::Strategy::Fifo` and `ElectricSlide::Queue#queue_strategy` - this may be useful if you want some kind of special prioritization, for example with VIP callers.
* For now, all agents must be on the phone. If an agent hangs up, he is removed from the queue

TODO:
* Example for using Matrioska to offer Agents and Callers interactivity while waiting
* How to handle Agent logout only from the phone?
* Is there a way to get some kind of default MOH for Callers?
* Example integrating with external presence events (like XMPP)

Example Queue
-------------

```Ruby
class SupportQueue < ElectricSlide::Queue
  name "Support Queue"

  caller_strategy :fifo
  agent_strategy  :fifo

  while_waiting_for_agent do
    # Default block to be looped on queued calls (callers) while waiting for an agent
  end

  while_waiting_for_calls do
    # Default block to be looped on agent calls while waiting for a caller
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
    end
    
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

    SupportQueue.work_queue(agent) # Blocks while agent works the queue
  end
end
```


