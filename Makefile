DIST	:= "ubuntu:latest"
COSMOS_RPM_KEY ?= $(CURDIR)/rpm/kushal_rpm.pub

cosmos:
	fab all cosmos

upgrade:
	fab upgrade

tag:
	./bump-tag

test_in_docker:
	docker run --rm -it \
		-v "${CURDIR}:/multiverse:ro" \
		$(if $(COSMOS_RPM_KEY),-v "$(COSMOS_RPM_KEY):/run/multiverse-rpm-key.pub:ro") \
		$(DIST) /multiverse/scripts/test-in-docker.sh

# Local development packages. Signing is a separate release operation.
.PHONY: cosmos-rpm
cosmos-rpm:
	docker buildx build --build-context multiverse-apt=global/overlay/etc/cosmos/apt \
		--output type=local,dest=build/cosmos-rpm packaging/cosmos
