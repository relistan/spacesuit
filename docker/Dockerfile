FROM elixir:1.6.0

ADD . /spacesuit

WORKDIR /spacesuit
RUN mix local.rebar --force
RUN mix local.hex --force
RUN mix deps.get
RUN mix compile

EXPOSE 8080

CMD [ "mix", "run", "--no-halt" ]
