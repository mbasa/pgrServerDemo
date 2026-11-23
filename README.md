# pgrserver_demo

A flutter application to view and test major services of the [pgrServer](https://github.com/mbasa/pgrServer)
routing engine. This is used mainly for the MacOS desktop, although it will work as a Web 
as well as a mobile application. 

### Pre-requiste

A working pgrServer application service is a pre-requisite. Modify 

``` lib/res/RestParams.dart```

to point to the pgrServer if not  located on the default localhost.

### Getting the Application

A MacOS binary, an Android apk, an unsigned IOS ipa, and a 
web application package can all be downloaded fom the *Release* of
this application. 

### Building as a Native Application

To build a `MacOS Desktop` application, run:

```shell script
flutter build macos --release
``` 

### Building as an Android Application

To build an `Android` application, run:

```shell script
flutter build apk --release
``` 

### Building as a Web Application

To build a `Web` application, run:

```shell script
flutter build web --release --wasm --base-href /pgrserver_demo/
```

and copy the contents of `build/web/` to the web server directory that
matches the base href (e.g. `http://<host>/pgrserver_demo/`).

* `--base-href` must match the path the application is served from, and must
  start and end with a `/`. There is no need to edit `web/index.html`; the
  value is inserted at build time. Omit it when serving from the site root.
* `--wasm` builds both a WebAssembly and a JavaScript version. Chromium-based
  browsers (Chrome, Edge) load the faster WebAssembly version; Safari, Firefox
  and all browsers on iOS automatically fall back to JavaScript. Omit
  `--wasm` to build the JavaScript version only.
* The web server must serve `.wasm` files as `application/wasm` and `.mjs`
  files as `text/javascript`.
* The pgrServer URL in `lib/res/RestParams.dart` must not end with a `/`.
  If pgrServer is on a different host or port than the web application, it
  must send CORS headers. If the application is served over `https`, the
  pgrServer URL must also be `https`.

To check whether a browser is running the WebAssembly or the JavaScript
version, open the settings (gear) dialog: it shows `Web runtime: Wasm` or
`Web runtime: JS`.


### Sanple Screenshots

* Shortest Path Searches
![Alt text](pics/img1.png?raw=true)
![Alt text](pics/img2.png?raw=true)
![Alt text](pics/img2_1.png?raw=true)

* Driving Distance
![Alt text](pics/img3.png?raw=true)
![Alt text](pics/img3_1.png?raw=true)

* VRP Solution Searches
![Alt text](pics/img4.png?raw=true)
![Alt text](pics/img5.png?raw=true)


