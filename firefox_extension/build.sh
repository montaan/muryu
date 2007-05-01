#!/bin/bash

mkdir -p muryu_uploader_buildtmp/chrome/content/muryu &&
cd muryu_uploader &&
cp install.js install.rdf chrome.manifest ../muryu_uploader_buildtmp &&
cd chrome/content/muryu &&
cp muryu.js muryu.xul contents.rdf ../../../../muryu_uploader_buildtmp/chrome/content/muryu &&
cd ../../../../muryu_uploader_buildtmp/chrome
zip -r muryu.jar * &&
rm -r content &&
cd .. &&
zip -r ../muryu_uploader.xpi * &&
cd .. &&
rm -r muryu_uploader_buildtmp &&
echo && echo "Done!"
