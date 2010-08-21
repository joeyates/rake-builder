#import "main.h"

int main(void)
{
  NSAutoreleasePool *pool    = [ [ NSAutoreleasePool alloc ] init ];
  NSString *text             = @"Written by Objective-C";
  NSString *filename         = @"./rake-builder-testfile.txt";
  NSData *data               = [ text dataUsingEncoding: NSASCIIStringEncoding ];
  NSFileManager *filemanager = [NSFileManager defaultManager];
  BOOL written               = [ filemanager createFileAtPath: filename contents: data attributes: nil ];
  if( ! written ) {
    NSLog( @"Failed to write to file" );
  }

  [ pool release ];

  return 0;
}
