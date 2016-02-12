# [develop](https://github.com/adhearsion/electric_slide)

# [0.5.0](https://github.com/adhearsion/electric_slide/compare/v0.4.2...v0.5.0) - [2016-02-12](https://rubygems.org/gems/adhearsion/versions/0.5.0)
  * API Breakage: Fixed priority strategy now ensures that the same agent cannot be in multiple priorities

# [0.4.2](https://github.com/adhearsion/electric_slide/compare/v0.4.1...v0.4.2) - [2016-02-04](https://rubygems.org/gems/adhearsion/versions/0.4.2)
  * Bugfix: FixedPriority now correctly checks out agents in priority order.

# [0.4.1](https://github.com/adhearsion/electric_slide/compare/v0.4.0...v0.4.1) - [2016-01-04](https://rubygems.org/gems/adhearsion/versions/0.4.1)
  * Bugfix: Don't hand out internal CallQueue references to Agents - thread-safety

# [0.4.0](https://github.com/adhearsion/electric_slide/compare/v0.3.0...v0.4.0) - [2015-12-17](https://rubygems.org/gems/adhearsion/versions/0.4.0)
  * Change `ElectricSlide::Agent` `#presence=` method name to `#update_presence`. It will also accept one more parameter called `extra_params`, a hash that holds application specific parameters that are passed to the presence change callback.
  * `ElectricSlide::CallQueue#add_agent` will no longer wait for a connection attempt to complete before returning

# [0.3.0](https://github.com/adhearsion/electric_slide/compare/v0.2.0...v0.3.0) - [2015-12-01](https://rubygems.org/gems/adhearsion/versions/0.3.0)
  * Trigger an agent "presence change" callback when the agent is removed from the queue
  * Bugfix: Fix `NameError` exception when referencing namespaced constant `Adhearsion::Call::ExpiredError` in injected `Adhearsion::Call#active?` method
  * Provide Electric Slide with a way to check if a queue with a given set of attributes is valid/can be instantiated before Electric Slide adds it to the supervision group. The supervisor will crash if its attempt to create the queue raises an exception.
  * Add support for changing queue attributes
    * API Breakage: Setting queue connection type to an invalid value will now raise an `ElectricSlide::CallQueue::InvalidConnectionType` exception instead of `ArgumentError`
    * API Breakage: Setting queue agent return method to an invalid value will now raise an `ElectricSlide::CallQueue::InvalidRequeueMethod` exception instead of `ArgumentError`
  * List created queues by name via `ElectricSlide.queues_by_name`
  * Set `:agent` call variable on queued call when connecting calls
  * API Breakage: Queues must now be Celluloid actors responding to the standard actor API. `ElectricSlide::CallQueue.work` is removed in favour of `.new`.
  * API Breakage: Prevent an unqueued agent from being returned to the queue - this avoids calls after logging out
  * API Breakage: An agent's presence should be :after_call if they are not automatically returned to being available
  * API Breakage: Store queued/connected timestamps on calls
  * API Breakage: Remove abandoned calls from the queue
  * Set agent `#call` attribute to outbound call made to agent in :call mode
  * Prevent an agent from being added to the queue more than once
  * Added Travis CI configuration
  * Lots more test coverage - still bad

# [0.2.0](https://github.com/adhearsion/electric_slide/compare/bb3b1b3e7f6d0926d0a9f462520e1f6d0c277adf...v0.2.0) - [2015-07-23](https://rubygems.org/gems/adhearsion/versions/0.2.0)
  * ¯\\_(ツ)_/¯
