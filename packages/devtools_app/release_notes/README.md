## Generating Release notes
- Release notes for DevTools are hosted on the flutter website (see [archive](https://docs.flutter.dev/tools/devtools/release-notes)).
- To add release notes for the latest release, create a PR with the appropriate changes for your release.
    - The [NEXT_RELEASE_NOTES.md](NEXT_RELEASE_NOTES.md) file contains the running release notes for the current version.
    - see example [PR](https://github.com/flutter/website/pull/6791) for an example of how to add those to the Flutter website.
    - NOTE: when adding images, be cognizant that the images will be rendered in a relatively small window in DevTools, and they should be sized accordingly.

- Once you are satisfied with the release notes, push up a PR to the `flutter/website` repo, and then 
proceed to the testing steps below.

### Testing the release notes in DevTools
Once you push up your `flutter/website` PR, wait for the `github-actions` bot to stage your changes
to firebase. Open the link and navigate to the release notes you want to test. Be sure to add `-src.md`
to the url to get the raw json. The url should look something like:
```
https://flutter-docs-prod--pr8928-dt-notes-links-b0b33er1.web.app/tools/devtools/release-notes/release-notes-2.24.0-src.md
```
- Copy this url and set `_debugReleaseNotesUrl` in `release_notes.dart` to this value.

- Run DevTools and the release notes viewer should open with the markdown at the url you provided.

- Verify the release notes viewer displays the new release notes as expected. Some issues to watch out for are broken images or 'include_relative' lines in the markdown that don't load properly.
