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
my_queue = ElectricSlide.create :my_queue

# Another way to get a handle on a queue
ElectricSlide.create :my_queue
my_queue = ElectricSlide.get_queue :my_queue
```


Example CallController for Queued Call
--------------------------------------

```Ruby
class EnterTheQueue < Adhearsion::CallController
  def run
    answer

    # Play music-on-hold to the caller until joined to an agent
    # TODO: Create an ElectricSlide helper to wrap up this function
    # with optional looping of playback
    player = play 'http://moh-server.example.com/stream.mp3'
    call.on_joined do
      player.stop!
    end

    ElectricSlide.get_queue(:my_queue).enqueue call
    # Blocks until call is done talking to the agent

    say "Goodbye"
  end
end
```


Adding an Agent to the Queue
----------------------------

ElectricSlide expects to be given a objects that quack like an agent. You can use the built-in `ElectricSlide::Agent` class, or you can provide your own.

To add an agent who will receive calls whenever a call is enqueued, do something like this:

```Ruby
agent = ElectricSlide::Agent.new id: 1, address: 'sip:agent1@example.com', presence: :available
ElectricSlide.get_queue(:my_queue).add_agent agent
```

To inform the queue that the agent is no longer available you *must* use the ElectricSlide queue interface. /Do not attempt to alter agent objects directly!/

```Ruby
ElectricSlide.update_agent 1, presence: offline
```

If it is more convenient, you may also pass `#update_agent` an Agent-like object:

```Ruby
agent = ElectricSlide::Agent.new id:1, address: 'sip:agent1@example.com', presence: :offline
ElectricSlide.update_agent 1, agent
```

