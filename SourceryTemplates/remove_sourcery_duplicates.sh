#!/bin/bash

sed '/MARK: removeData/,/MARK: removeData/d' $PROJECT_DIR/LaunchDarkly/GeneratedCode/mocks.generated.swift > mock-tmp && mv mock-tmp $PROJECT_DIR/LaunchDarkly/GeneratedCode/mocks.generated.swift
