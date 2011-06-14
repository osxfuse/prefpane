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

# A script to generate a property list config. This script should be
# run from an Xcode shell-script build phase because it relies on some
# environment variables that Xcode defines.
#
# Example:
#   cd "${TARGET_BUILD_DIR}" \
#   && bash enginerunner-plist-generator.sh > enginerunner.plist
#

if [ ${UPDATE_ENGINE_VERSION:=undefined} = "undefined" ]; then
  echo "UPDATE_ENGINE_VERSION env var not supplied.  Exiting"
  exit 1
fi


dmg_name="EngineRunner-${UPDATE_ENGINE_VERSION}.dmg"
now=$(date +%Y-%m-%d)
size=$(stat -f%z "$dmg_name")
hash=$(./kshash.sh "$dmg_name" | awk '{print $2}')

cat <<__END_CONFIG
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<!-- Created ${now} -->
<plist version="1.0">
<dict>
  <key>Rules</key>
  <array>
    <dict>
      <key>ProductID</key>
      <string>EngineRunner</string>
      <key>Predicate</key>
      <string>Ticket.version != '${UPDATE_ENGINE_VERSION}'</string>
      <key>Codebase</key>
      <string>http://update-engine.googlecode.com/files/${dmg_name}</string>
      <key>Size</key>
      <string>${size}</string>
      <key>Hash</key>
      <string>${hash}</string>
    </dict>
  </array>
</dict>
</plist>
__END_CONFIG
