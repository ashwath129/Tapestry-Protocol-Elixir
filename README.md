# Tapestry

Tapestry algorithm using actor model in Elixir based on the research paper - https://pdos.csail.mit.edu/~strib/docs/tapestry/tapestry_jsac03.pdf

Extract the contents of the zip folder in your desired location. 

After extracting, open cmd/terminal to the folder which has the mix.exs file 

Run the program by giving the command:  “mix run tapestry.exs <number of nodes> <number of requests>”  
  
The output will print the maximum number of hops and the run terminates when the peer performs the given number of requests

Largest Network Handled: Number of nodes - 10000 , Number of Requests - 200


## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `tapestry` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:tapestry, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/tapestry](https://hexdocs.pm/tapestry).

