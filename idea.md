Imagine an agent that does some thing. For starters, we will assume that thing is oneshot. Maybe soon we will evolve. Thus, the agent mre or less works like this...

1. input prompt + trigger
2. we capture state
3. agent does its thing with tools
4. agent outputs some message and maybe side effects
5. we capture state, transcript, tool calls, message

Let's assume now we have a proper harness. It looks like this:

'''
harness(input, trigger) --> output
'''

Thus we can write our own harness that is a tester. This tester can start with some test corpus that is representative of a valid input. It can then continuously mutate that input in pursuit of covering as many interesting end states, or outputs, as possible. In doing so, it will try to cause the agent to fail the evals and scorers run against it.

This is basically agentic fuzz testing.
