.PHONY: all prereqs cluster gateway schedule serve observe verify loadtest clean

all: prereqs cluster gateway schedule serve observe

prereqs:
	./scripts/00-prereqs.sh

cluster:
	./scripts/01-cluster.sh

gateway:
	./scripts/02-gateway.sh

schedule:
	./scripts/03-schedule.sh

serve:
	./scripts/04-serve.sh

observe:
	./scripts/05-observe.sh

verify:
	./scripts/verify.sh

loadtest:
	./scripts/06-loadtest.sh

clean:
	./scripts/cleanup.sh
