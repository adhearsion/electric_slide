Electric Slide - Simple Call Distribution for Adhearsion
====================================================================

This library implements a simple FIFO (First-In, First-Out) call queue for Adhearsion.

To ensure proper operation, a few things are assumed:

* Agents will only be logged into a single queue at a time
    If you have two types of agents (say "support" and "sales") then you should have two queues, each with their own pool of agents
* Agent authentication will happen before entering the queue - it is not the queue's concern
* The strategy for callers is FIFO: the caller who has been waiting the longest is the next to get an agent
* Queues will be implemented as a Celluloid Actor, which should protect the call selection strategies against race conditions
* There are two ways to connect an agent:
  - If the Agent object provides an `address` attribute, and the queue's `connection_type` is set to `call`, then the queue will call the agent when a caller is waiting
  - If the Agent object provides a `call` attribute, and the queue's `connection_type` is set to `bridge`, then the call queue will bridge the agent to the caller. In this mode, the agent hanging up will log him out of the queue

TODO:
* Example for using Matrioska to offer Agents and Callers interactivity while waiting
* How to handle MOH

## WARNING!

While you can have ElectricSlide keep track of custom queues, it is recommended to use the built-in CallQueue object.

The authors of ElectricSlide recommend NOT to subclass, monkeypatch, or otherwise alter the CallQueue implementation, as the likelihood of creating subtle race conditions is high.

Example Queue
-------------

```ruby
my_queue = ElectricSlide.create :my_queue, ElectricSlide::CallQueue

# Another way to get a handle on a queue
ElectricSlide.create :my_queue
my_queue = ElectricSlide.get_queue :my_queue
```


Example CallController for Queued Call
--------------------------------------

```ruby
class EnterTheQueue < Adhearsion::CallController
  def run
    answer

    # Play music-on-hold to the caller until joined to an agent
    player = play 'http://moh-server.example.com/stream.mp3', repeat_times: 0
    call.on_joined do
      player.stop!
    end

    ElectricSlide.get_queue(:my_queue).enqueue call

    # The controller will exit, but the call will remain up
    # The call will automatically hang up after speaking to an agent
    call.auto_hangup = false
  end
end
```


Adding an Agent to the Queue
----------------------------

ElectricSlide expects to be instances of the `ElectricSlide::Agent` class. This is designed to be extended with custom functionality when necessary.

To add an agent who will receive calls whenever a call is enqueued, do something like this:

```ruby
agent = ElectricSlide::Agent.new id: 1, address: 'sip:agent1@example.com', presence: :available
ElectricSlide.get_queue(:my_queue).add_agent agent
```

To inform the queue that the agent is no longer available you *must* use the ElectricSlide queue interface. **_Do not attempt to change agent objects directly!_**

```ruby
ElectricSlide.update_agent 1, presence: offline
```

If it is more convenient, you may also pass `#update_agent` an Agent-like object:

```ruby
options = {
  id: 1,
  address: 'sip:agent1@example.com',
  presence: :unavailable
}
agent = ElectricSlide::Agent.new options
ElectricSlide.update_agent 1, agent
```

The possible presence states for an Agent are:

* `:available` - Waiting for a call
* `:on_call` - Currently connected to a call
* `:after_call` - In a quiet period after completing a call and before being made available again. This is only encountered with a manual agent return strategy.
* `:unavailable` - Agent is not available (on break, offline, etc)

Note that an `:unavailable` agent still counts as an agent in the queue, but will not be sent any calls. Make sure to remove agents, even unavailable ones, when agents sign out by using the `#remove_agent` method.

Switching connection types
--------------------------

ElectricSlide provides two methods for connecting callers to agents:
- `:call`: (default) If the Agent object provides an `address` attribute, and the queue's `connection_type` is set to `call`, then the queue will call the agent when a caller is waiting
- `:bridge`: If the Agent object provides a `call` attribute, and the queue's `connection_type` is set to `bridge`, then the call queue will bridge the agent to the caller. In this mode, the agent hanging up will log him out of the queue

To select the connection type, specify it when creating the queue:

```ruby
ElectricSlide.create_queue :my_queue, ElectricSlide::CallQueue, connection_type: :bridge
```

Selecting an Agent distribution strategy
----------------------------------------

Different use-cases have different requirements for selecting the next agent to take a call.  ElectricSlide provides two strategies which may be used. You are also welcome to create your own distribution strategy by implementing the same interface as described in `ElectricSlide::AgentStrategy::LongestIdle`.

To select an agent strategy, specify it when creating the queue:

```ruby
ElectricSlide.create_queue :my_queue, ElectricSlide::CallQueue, agent_strategy: ElectricSlide::AgentStrategy::LongestIdle
```

Two strategies are provided out-of-the-box:

* `ElectricSlide::AgentStrategy::LongestIdle` selects the agent that has been idle for the longest amount of time.
* `ElectricSlide::AgentStrategy::FixedPriority` selects the agent with the lowest numeric priority first.  In the event that more than one agent is available at a given priority, then the agent that has been idle the longest at the lowest numeric priority is selected.

Custom Agent Behavior
----------------------------

If you need custom functionality to occur whenever an Agent is selected to take a call, you can use the callbacks on the Agent object:

* `on_connect`
* `on_disconnect`

Confirmation Controllers
------------------------

In case you need to execute a confirmation controller on the call that is placed to the agent, such as "Press 1 to accept the call", you currently need to pass in the confirmation class name and the call object as metadata in the `call_options_for` callback in your `ElectricSlide::Agent` subclass.

```ruby
# an example from the Agent subclass
def dial_options_for(queue, queued_call)
  {
    from: caller_digits(queued_call.from),
    timeout: on_pstn? ? APP_CONFIG.agent_timeout * 3 : APP_CONFIG.agent_timeout,
    confirm: MyConfirmationController,
    confirm_metadata: {caller: queued_call, agent: self},
  }
end
```

You then need to handle the join in your confirmation controller, using for example:

```ruby
call.join metadata[:caller] if confirm!
```

where `confirm!` is your logic for deciding if you want the call to be connected or not. Hanging up during the confirmation controller or letting it finish without any action will result in the call being sent to the next agent.
