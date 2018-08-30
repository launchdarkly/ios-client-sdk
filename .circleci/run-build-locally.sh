# A script that triggers a circleci build from the command line
# Script from https://circleci.com/docs/2.0/examples/#video-test-your-config-file-locally
# Usage: From the project folder (e.g. 'ios-client') run 'bash .circleci/run-build-locally.sh'
#   Set the url to run in this format
#   https://circleci.com/api/v1.1/project/<source, eg. github>/<user name>/<project name>/tree/<branch name>
# Dependencies:
#   CIRCLE_TOKEN must be defined in the environment.
# See https://circleci.com/docs/2.0/managing-api-tokens/#creating-a-personal-api-token
curl --user ${CIRCLE_TOKEN}: \
     --request POST \
     --form config=@.circleci/config.yml \
     --form notify=false \
        https://circleci.com/api/v1.1/project/github/launchdarkly/ios-client/tree/master
