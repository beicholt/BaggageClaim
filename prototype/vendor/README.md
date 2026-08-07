three.js r185, bundled as a classic script exposing the THREE global.

Rebuilt with:
  npm i three@0.185.1 esbuild
  echo "export * from 'three';" > three-entry.js
  npx esbuild three-entry.js --bundle --format=iife --global-name=THREE \
    --minify --legal-comments=none --outfile=three.global.js

It is vendored rather than pulled from a CDN because the prototype has to open
straight off the filesystem on a phone, and ES module imports fail under
file://. See LICENSE (MIT).
