# pgrserver_demo

A flutter application to view and test major services of the [pgrServer](https://github.com/mbasa/pgrServer)
routing engine. This is used mainly for the MacOS desktop, although it will work as a Web 
as well as a mobile application. 

### Pre-requiste

A working pgrServer application service is a pre-requisite. Modify 

``` lib/res/RestParams.dart```

to point to the pgrServer if not  located on the default localhost.

### Building as a Native Application

To build a `MacOS Desktop` application, run:

```shell script
flutter build macos --no-sound-null-safety
``` 

### Building as a Web Application

To build a `Web` application, run:

```shell script
flutter build web --release
``` 

then edit `web/index.html` and change the `base href` to an appropriate web app name

```
<base href="/pgrserver_demo/">
```


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


