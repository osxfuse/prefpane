Hi!

Welcome to the Actions sample.  This is a simple app that uses the
Update Engine action processor classes to do a bit of network
programming:

1) First it gets a catalog file from an URL, which contains a list of
   of image files to load, using UECatalogLoaderAction.  It processes
   the catalog file and emits an array of URL strings through the action
   pipe.

2) Then UECatalogFilterAction filters the catalog based on a predicate.
   I treads the array of URL strings from the action pipe and emits a
   filtered array.

3) Then it downloads the filtered images and displays them in a window.
   The UECatalogDownloadAction class uses a sub-processor that runs
   a bunch of UEImageDownloadActions.

The master calss is AppController.  That's a good place to start reading
the code.


The source files:

AppController.[hm] -- The main controller class, handling the window that the
                      user interacts with

UECatalogDownloadAction.[hm] -- Processes an array of URL strings, using a
                                UEImageDownloadActions for each one.

UECatalogFilterAction.[hm] -- Filters an array of strings based with 
                              a predicate.

UECatalogLoaderAction.[hm] -- Reads a catalog file from the internet and splits
                              it into an array of strings.

UEImageDownloadAction.[hm] -- Downloads individual image files.

UENotifications.[hm] -- Helper function for letting action classes present
                        messages in the user interface.

main.m -- Standard Cocoa boilerplate main() function.

