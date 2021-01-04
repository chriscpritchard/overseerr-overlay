# overseerr-overlay
A portage overlay to install overseerr
## Instructions for Use
You can easily add this repository using eselect repository:

```bash
eselect repository add overseerr-overlay git https://github.com/chriscpritchard/overseerr-overlay.git
```

To install overseerr, just run:

```bash
emerge www-apps/overseerr
```

## Live Ebuild
A live ebuild (`=www-apps/overseerr-9999`) is available in this repository. This will install the latest version of overseerr on the develop branch, which may not be in a usable state, to use, you will need to add this package to your accept_keywords directory.

This can be accomplished by running the following command:

```bash
emerge --autounmask-write --autounmask --autounmask-write "=www-apps/overseerr-9999"
```

**Only install this version if you know what you are doing**

Once installed, you will not be notified of updates, so you will need to update using

```bash
emerge @live-rebuild
```

or use `app-portage/smart-live-rebuild`


