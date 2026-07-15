<!--
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/tools/pub/writing-package-pages).

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/to/develop-packages).
-->

## Getting started
# FSK - Flutter Scene Kit
A lightweight package for integrating interactive 2D and 3D hardware accelerated content into your flutter apps. FSK is a layer on top of the flutter_angle package.
## Why Does This Package Exist?
When I started FSK, Flutter STILL had no officially sanctioned method to integrate performant, 
cross-platform interactive 3D content into flutter apps. I wanted to add 3D content to multiple
apps that I was working on, and thus FSK was born as a reusable package.

While Flutter_angle provides a low level API conformant with OpenGL ES, there is still quite a lot of additional code required to create interactive 3D content.
FSK simplifies integrating such content into flutter apps by providing a reusable framework to automate much of the drudgery.

## Features

FSK provides:
* Management of OpenGL resources like Index Buffers, Vertex Buffers, Shaders, Textures and Materials
* Efficient loading of vertex data using native buffers
* A framework to create custom shaders with type-safe access to uniforms from dart
* Widgets for integrating real-time animated scenes into the flutter widget hierarchy
* Integration of pointer and touch events into 3D scenes using NavigationDelegates
* A sample OrbitView NavigationDelegate
* A framework for rendering scenes in multiple layers and combining them
* Screen Space Overlays
* A BitMap font system for creating simple 2D texture mapped text that can be drawn inside FSK scenes

Additionally, FSK supplies supporting code for:
* Triangle level 3D picking of geometry using ray casting
* Operations for clipping polylines, and tessellating them into triangle meshes
* Simple Wavefront OBJ file loader
* A set of example applications demonstrating most features
## Getting Started
To use FSK, add it to your pubspec
```
 $ flutter pub add fsk
```

Include FSK in your main, and initialize the library

```
import 'package:fsk/fsk.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize the FSK library in main, after WidgetsFlutterBinding.ensureInitialized();
  FSK().initPlatformState();
  
  ...
  
}
```
Then create a custom subclass of Scene to contain your custom rendering code.

```
class MyCustomScene extends Scene {
...
}
```
Instantiate that scene somewhere exactly once. In this example, the scene is instantiated in the initState method in a StatefulWidget.
After instantiating the Scene, register the scene with FSK using registerSceneAndAllocateTexture.

FSK renders scenes to a texture in a background operation, using SingleTickerProviderStateMixin to draw the 3D scene at whatever frame rate the application is running at.
The RenderToTexture widget then composites the rendered output into the flutter_app.

```
class TestAppState extends State<TestApp> {
late MyCustomScene myScene;

  @override
  void initState() {
    super.initState();
    myScene = MyCustomScene();
    FSK().registerSceneAndAllocateTexture(myScene);
  }
```
Finally, somewhere in your widget tree, place the 3D scene using RenderToTexture

```
Scaffold(body: RenderToTexture(scene: myScene));
```

Alternatively, use InteractiveRenderToTexture, which takes a second argument of a NavigationDelegate.
InteractiveRenderToTexture creates a GestureRecognizer and a Listener and passes pointer and touch events to the navigation delegate.
The navigation delegate then creates modelview and projection matrices to control the view of the InteractiveRenderToTexture widget.

In this example, the FSK provided OrbitView navigation delegate is used, which allows the user to spin the view using mouse/touch events.
You can create your own custom NavigationDelegates to do whatever kind of navigation/interaction you need.
```
  late MyCustomScene myScene;
  late OrbitView orbitView;
  @override
  void initState() {
    super.initState();
    myScene = MyCustomScene();
    orbitView = OrbitView();
    FSK().registerSceneAndAllocateTexture(myScene);
  }

Scaffold(body: InteractiveRenderToTexture(
    navigationDelegate: orbitView
    scene: myScene));
```

You may instantiate multiple custom scenes and register them with FSK. You may place multiple RenderToTexture widgets in your app.
By default, FSK also detects when a scene is not visible and pauses its rendering output.

## Contributing
FSK is in its very early development stages and is being developed to support my personal projects.
Contributions on all fronts are welcomed, please contact me if you want to help out.
TODO: List prerequisites and provide or point to information on how to
start using the package.

## Usage

TODO: Include short and useful examples for package users. Add longer examples
to `/example` folder.

```dart
const like = 'sample';
```

## Additional information

TODO: Tell users more about the package: where to find more information, how to
contribute to the package, how to file issues, what response they can expect
from the package authors, and more.
