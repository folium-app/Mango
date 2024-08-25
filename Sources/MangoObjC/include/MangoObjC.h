//
//  MangoObjC.h
//  Mango
//
//  Created by Jarrod Norwell on 8/8/2024.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, SNESRomType) {
    SNESRomTypePAL = 0,
    SNESRomTypeNTSC = 1
};

@interface MangoObjC : NSObject
+(MangoObjC *) sharedInstance NS_SWIFT_NAME(shared());

-(void) insertCartridge:(NSURL *)url NS_SWIFT_NAME(insert(cartridge:));

-(void) step;

-(SNESRomType) type;

-(int16_t*) audioBuffer;
-(uint8_t*) videoBuffer;

-(NSString *) titleForCartridgeAtURL:(NSURL *)url;

-(void) button:(int)button player:(int)player pressed:(BOOL)pressed;
@end

NS_ASSUME_NONNULL_END
