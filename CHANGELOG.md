# [develop](https://github.com/adhearsion/electric_slide)
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
