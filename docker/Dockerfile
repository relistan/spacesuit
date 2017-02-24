FROM elixir:1.4.1

ADD . /spacesuit

WORKDIR /spacesuit
RUN mix local.rebar --force
RUN mix local.hex --force
RUN mix deps.get
RUN mix compile

EXPOSE 8080

CMD [ "iex", "-S", "mix" ]
