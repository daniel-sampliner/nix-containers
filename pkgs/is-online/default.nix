# SPDX-FileCopyrightText: 2024 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

{ writers
, coreutils
, curl
}: writers.writeExecline { } "/bin/is-online" ''
  backtick -E url { ${coreutils}/bin/shuf -n1 ${./endpoints} }
  backtick -E rc { ${curl}/bin/curl
    --max-time 1 --retry 5 --retry-max-time 10
    --fail --silent --show-error
    --write-out "%{response_code}\n" --output /dev/null $url }

  eltest $rc -eq 204
''
