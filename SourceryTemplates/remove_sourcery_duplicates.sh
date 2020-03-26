#!/bin/bash

sed '138,147d' $PROJECT_DIR/LaunchDarkly/GeneratedCode/mocks.generated.swift | tee $PROJECT_DIR/LaunchDarkly/GeneratedCode/mocks.generated.swift

#sed '/MARK: removeData/,/^$/d' $PROJECT_DIR/LaunchDarkly/GeneratedCode/mocks.generated.swift | tee $PROJECT_DIR/LaunchDarkly/GeneratedCode/mocks.generated.swift

#awk 'BEGIN { del=0 } /MARK: removeData/ { del=1 } del<=0 { print } /MARK: removeData/ { del -= 1 }' $PROJECT_DIR/LaunchDarkly/GeneratedCode/mocks.generated.swift | tee $PROJECT_DIR/LaunchDarkly/GeneratedCode/mocks.generated.swift