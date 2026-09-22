JUNIT_URL := https://repo1.maven.org/maven2/org/junit/platform/junit-platform-console-standalone/1.10.0/junit-platform-console-standalone-1.10.0.jar
JUNIT_JAR := libs/junit.jar

SPOTBUGS_URL := https://repo1.maven.org/maven2/com/github/spotbugs/spotbugs/4.8.6/spotbugs-4.8.6.tgz
SPOTBUGS_DIR := libs/spotbugs
SPOTBUGS_BIN := $(SPOTBUGS_DIR)/bin/spotbugs

SRCS := $(shell find src -name '*.java' 2>/dev/null)
TESTS := $(shell find test -name '*.java' 2>/dev/null)

.PHONY: deps build test spotbugs clean

deps: $(JUNIT_JAR)

$(JUNIT_JAR):
	@mkdir -p libs
	@curl -sSL -o $@ $(JUNIT_URL)

$(SPOTBUGS_BIN):
	@mkdir -p libs
	@curl -sSL -o /tmp/spotbugs.tgz $(SPOTBUGS_URL)
	@tar -xzf /tmp/spotbugs.tgz -C libs
	@mv libs/spotbugs-* $(SPOTBUGS_DIR)
	@chmod +x $(SPOTBUGS_DIR)/bin/*

build: deps
	@mkdir -p build
	javac --release 17 -d build -cp $(JUNIT_JAR) $(SRCS) $(TESTS)

test: build
	java -jar $(JUNIT_JAR) --class-path build --scan-class-path

spotbugs: build $(SPOTBUGS_BIN)
	$(SPOTBUGS_BIN) -textui -effort:max -low \
		build/PriceEngine.class build/Order.class build/Order\$$Line.class \
		build/Customer.class build/Money.class

clean:
	rm -rf build libs
