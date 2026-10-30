# Ruby oracle only; formula.bend implementation and tooling do not depend on Ruby.
FROM docker.io/library/ruby@sha256:24ea89e8103548bc02b53ae5212313afaccc79d11c5f93982bd4de298ec0934d
RUN apk add --no-cache git
