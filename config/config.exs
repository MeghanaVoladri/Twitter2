# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :twitter,
  ecto_repos: [TwitterClone.Repo]

# Configures the endpoint
config :twitter, TwitterCloneWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "x0O86qGUGB7d16uDaSb/OmTndjMIUwdSCofih2L3aWuEkegB1ldDsPqSFHV6yplt",
  render_errors: [view: TwitterCloneWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: TwitterClone.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
