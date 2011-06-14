#!/bin/bash
# Copyright 2008 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This script takes a list of file names as arguments and outputs
# each file's base64 encoded SHA-1 hash.

PATH=/bin:/usr/bin; export PATH

if [ $# -eq 0 ]; then
  echo "Usage: kshash.sh file1 ..."
  exit 1
fi

for file in "$@"; do
  h=$(openssl sha1 -binary "$file" | openssl base64)
  s=$(stat -f%z "$file")
  printf "%20s:\t%s\t%s\n" "$file" $h $s
done
