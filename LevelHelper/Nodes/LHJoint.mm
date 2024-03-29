//  This file was generated by LevelHelper
//  http://www.levelhelper.org
//
//  LevelHelperLoader.mm
//  Created by Bogdan Vladu
//  Copyright 2011 Bogdan Vladu. All rights reserved.
////////////////////////////////////////////////////////////////////////////////
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//  The origin of this software must not be misrepresented; you must not
//  claim that you wrote the original software. If you use this software
//  in a product, an acknowledgment in the product documentation would be
//  appreciated but is not required.
//  Altered source versions must be plainly marked as such, and must not be
//  misrepresented as being the original software.
//  This notice may not be removed or altered from any source distribution.
//  By "software" the author refers to this code file and not the application 
//  that was used to generate this file.
//
////////////////////////////////////////////////////////////////////////////////
#import "LHJoint.h"

#ifdef LH_USE_BOX2D
#import "LHSettings.h"
#import "LevelHelperLoader.h"
#import "LHSprite.h"
#import "LHDictionaryExt.h"



@interface LHRopePoint : NSObject {
    CGPoint position;
    CGPoint oldPosition;
}

+(id)ropePoint;
-(void)setPosition:(CGPoint)pos;
-(CGPoint)position;

-(void)update;
-(void)applyGravity:(float)dt;

@end

@implementation LHRopePoint

+(id)ropePoint{    
#ifndef LH_ARC_ENABLED
    return [[[self alloc] init] autorelease];
#else
    return [[self alloc] init];
#endif
}

-(void)setPosition:(CGPoint)pos{
    oldPosition = pos;
    position = oldPosition;
}
-(CGPoint)position{
    return position;
}
-(void)update {
    CGPoint tempPos = position;
    position.x += position.x - oldPosition.x;
    position.y += position.y - oldPosition.y;
    oldPosition = tempPos;
}
-(void)applyGravity:(float)dt {
    
    b2World* world = [[LHSettings sharedInstance] activeBox2dWorld];
    
    if(world){
        b2Vec2 grav = world->GetGravity();
        
        position.x += grav.x*2.0f*dt;
        position.y += grav.y*2.0f*dt;
    }
    else{
        position.y -= 10.0f*dt; //gravity magic number
    }
}

-(void)dealloc{
#ifndef LH_ARC_ENABLED
    [super dealloc];
#endif
}
@end





@interface LHRopeStick : NSObject {
	LHRopePoint *pointA;
	LHRopePoint *pointB;
	float hypotenuse;
}
-(id)initWithRopePointA:(LHRopePoint*)a ropePointB:(LHRopePoint*)b;
+(id)ropeStickWithRopePointA:(LHRopePoint*)a ropePointB:(LHRopePoint*)b;

-(void)contract;
-(LHRopePoint*)ropePointA;
-(LHRopePoint*)ropePointB;
-(void)setRopePointA:(LHRopePoint*)a;
-(void)setRopePointB:(LHRopePoint*)b;

@end
@implementation LHRopeStick
-(id)initWithRopePointA:(LHRopePoint*)a ropePointB:(LHRopePoint*)b{
	
    if((self = [super init])) {
		pointA = a;
		pointB = b;
		hypotenuse = ccpDistance([pointA position],[pointB position]);
	}
	return self;
}

+(id)ropeStickWithRopePointA:(LHRopePoint*)a ropePointB:(LHRopePoint*)b
{
#ifndef LH_ARC_ENABLED
    return [[[self alloc] initWithRopePointA:a ropePointB:b] autorelease];
#else
    return [[self alloc] initWithRopePointA:a ropePointB:b];
#endif
}

-(void)dealloc{
    pointA = nil;
    pointB = nil;
    #ifndef LH_ARC_ENABLED
    [super dealloc];
    #endif
}

-(void)contract {
    CGPoint posA = [pointA position];
    CGPoint posB = [pointB position];
    
	float dx = posB.x - posA.x;
	float dy = posB.y - posA.y;
	float h = ccpDistance(posA,posB);
	float diff = hypotenuse - h;
	float offx = (diff * dx / h) * 0.5;
	float offy = (diff * dy / h) * 0.5;

    [pointA setPosition:ccp(posA.x - offx, posA.y - offy)];
    [pointB setPosition:ccp(posB.x + offx, posB.y + offy)];
}
-(LHRopePoint*)ropePointA {
	return pointA;
}
-(LHRopePoint*)ropePointB {
	return pointB;
}

-(void)setRopePointA:(LHRopePoint*)a{
    pointA = a;
}

-(void)setRopePointB:(LHRopePoint*)b{
    pointB = b;
}

@end










////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
@interface LevelHelperLoader (LH_JOINT_PRIVATE)
-(void)removeJoint:(LHJoint*)jt;
-(void)addJoint:(LHJoint*)jt;
@end

@implementation LevelHelperLoader (LH_JOINT_PRIVATE)
-(void)removeJoint:(LHJoint*)jt{
   // NSLog(@"REMOVE JOINT %@", [jt uniqueName]);
    if(!jt)return;
    [jointsInLevel removeObjectForKey:[jt uniqueName]];
}
-(void)addJoint:(LHJoint*)jt{
    if(jt){
        [jointsInLevel setObject:jt forKey:[jt uniqueName]];
    }
}
@end

@interface LHJoint (Private)
-(void) createBox2dJointFromDictionary:(NSDictionary*)dictionary;
@end

////////////////////////////////////////////////////////////////////////////////
@implementation LHJoint
@synthesize type;
@synthesize uniqueName;
@synthesize shouldDestroyJointOnDealloc;
////////////////////////////////////////////////////////////////////////////////
-(void) dealloc{		
  //  NSLog(@"LH Joint Dealloc %@", uniqueName);
    if(shouldDestroyJointOnDealloc)
        [self removeJointFromWorld];

    [self unscheduleAllSelectors];

    [rope_spriteSheet removeFromParentAndCleanup:YES];

#ifndef LH_ARC_ENABLED
    [rope_points release];
	[rope_sprites release];
	[rope_sticks release];
    [rope_textureName release];
    [uniqueName release];
	[super dealloc];
#endif
    rope_textureName = nil;
    uniqueName = nil;
    rope_points = nil;
	rope_sprites= nil;
	rope_sticks= nil;
}
////////////////////////////////////////////////////////////////////////////////
-(id) initWithDictionary:(NSDictionary*)dictionary 
                   world:(b2World*)box2d 
                  loader:(LevelHelperLoader*)pLoader{
    
    self = [super init];
    if (self != nil)
    {
        rope_wasCut = false;
        joint = 0;
        shouldDestroyJointOnDealloc = true;
        uniqueName = [[NSString alloc] initWithString:[dictionary stringForKey:@"UniqueName"]];
        tag = 0;
        type = LH_DISTANCE_JOINT;
        boxWorld = box2d;
        parentLoader = pLoader;
        
        [self createBox2dJointFromDictionary:dictionary];
    }
    return self;
}

////////////////////////////////////////////////////////////////////////////////
+(id) jointWithDictionary:(NSDictionary*)dictionary 
                    world:(b2World*)box2d 
                   loader:(LevelHelperLoader*)pLoader{

    if(!dictionary || !box2d || !pLoader) return nil;
    
#ifndef LH_ARC_ENABLED
    return [[[self alloc] initWithDictionary:dictionary world:box2d loader:pLoader] autorelease];
#else
    return [[self alloc] initWithDictionary:dictionary world:box2d loader:pLoader];
#endif

}


#ifdef B2_ROPE_JOINT_H
-(id) initRopeJointWithDictionary:(NSDictionary*)dictionary
                            joint:(b2RopeJoint*)ropeJt
                           loader:(LevelHelperLoader*)pLoader{
    
    self = [super init];
    if (self != nil)
    {
        rope_wasCut = true;
        joint = ropeJt;
        shouldDestroyJointOnDealloc = true;
        uniqueName = [[NSString alloc] initWithString:[dictionary stringForKey:@"UniqueName"]];
        tag = 0;
        type = LH_ROPE_JOINT;
        boxWorld = ropeJt->GetBodyA()->GetWorld();
        parentLoader = pLoader;
        [self prepareRopeJointsWithDictionary:dictionary];
        
#ifndef LH_ARC_ENABLED
        joint->SetUserData(self);
#else
        joint->SetUserData((__bridge void*)self);
#endif
    }
    return self;
}


+(id) ropeJointWithDictionary:(NSDictionary*)dictionary
                        joint:(b2RopeJoint*)ropeJt
                       loader:(LevelHelperLoader*)pLoader{
    
    if(!pLoader) return nil;
    
#ifndef LH_ARC_ENABLED
    return [[[self alloc] initRopeJointWithDictionary:dictionary joint:ropeJt loader:pLoader] autorelease];
#else
    return [[self alloc]  initRopeJointWithDictionary:dictionary joint:ropeJt loader:pLoader];
#endif

}
#endif

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
-(b2Joint*)joint{
    return joint;
}
////////////////////////////////////////////////////////////////////////////////
-(bool) removeJointFromWorld{
    

    if(0 != joint)
	{
        b2Body *body = joint->GetBodyA();
        
        if(0 == body)
        {
            body = joint->GetBodyB();
            
            if(0 == body)
                return false;
        }
        b2World* _world = body->GetWorld();
        
        if(0 == _world)
            return false;
        
        _world->DestroyJoint(joint);
        return true;
	}
    return false;
}
////////////////////////////////////////////////////////////////////////////////
-(LHSprite*) spriteA{
    if(joint)
        return [LHSprite spriteForBody:joint->GetBodyA()];
        
    return nil;
}
//------------------------------------------------------------------------------
-(LHSprite*) spriteB{
    if(joint)
        return [LHSprite spriteForBody:joint->GetBodyB()];
    
    return nil;    
}
//------------------------------------------------------------------------------
-(void)removeSelf{
    if(parentLoader){
        if(!boxWorld->IsLocked()){
            [parentLoader removeJoint:self];
        }
        else {
            [[LHSettings sharedInstance] markJointForRemoval:self];
        }
    }
}
//------------------------------------------------------------------------------
-(void) createBox2dJointFromDictionary:(NSDictionary*)dictionary
{
    joint = 0;
    
	if(nil == dictionary)return;
	if(boxWorld == 0)return;
    
    
    LHSprite* sprA  = [parentLoader spriteWithUniqueName:[dictionary stringForKey:@"ObjectA"]];
    b2Body* bodyA   = [sprA body];
	
    LHSprite* sprB  = [parentLoader spriteWithUniqueName:[dictionary stringForKey:@"ObjectB"]];
    b2Body* bodyB   = [sprB body];
	
    CGPoint sprPosA = [sprA position];
    CGPoint sprPosB = [sprB position];
    
    CGSize scaleA   = CGSizeMake([sprA scaleX], [sprA scaleY]);//[sprA realScale];
    CGSize scaleB   = CGSizeMake([sprB scaleX], [sprB scaleY]);//[sprB realScale];
    
    scaleA = [[LHSettings sharedInstance] transformedSize:scaleA forImage:[sprA imageFile]];
    scaleB = [[LHSettings sharedInstance] transformedSize:scaleB forImage:[sprB imageFile]];
    
	if(NULL == bodyA || NULL == bodyB ) return;
	
	CGPoint anchorA = [dictionary pointForKey:@"AnchorA"];
	CGPoint anchorB = [dictionary pointForKey:@"AnchorB"];
    
	bool collideConnected = [dictionary boolForKey:@"CollideConnected"];
	
    tag     = [dictionary intForKey:@"Tag"];
    type    = (LH_JOINT_TYPE)[dictionary intForKey:@"Type"];
    
	b2Vec2 posA, posB;
	
    float ptm = [[LHSettings sharedInstance] lhPtmRatio];
	float convertX = [[LHSettings sharedInstance] convertRatio].x;
//	float convertY = [[LHSettings sharedInstance] convertRatio].y;
    
    if(![dictionary boolForKey:@"CenterOfMass"])
    {        
        posA = b2Vec2((sprPosA.x + anchorA.x*scaleA.width)/ptm, 
                      (sprPosA.y - anchorA.y*scaleA.height)/ptm);
        
        posB = b2Vec2((sprPosB.x + anchorB.x*scaleB.width)/ptm, 
                      (sprPosB.y - anchorB.y*scaleB.height)/ptm);
        
    }
    else {		
        posA = bodyA->GetWorldCenter();
        posB = bodyB->GetWorldCenter();
    }
	
	if(0 != bodyA && 0 != bodyB)
	{
		switch (type)
		{
			case LH_DISTANCE_JOINT:
			{
				b2DistanceJointDef jointDef;
				
				jointDef.Initialize(bodyA, 
									bodyB, 
									posA,
									posB);
				
				jointDef.collideConnected = collideConnected;
				
				jointDef.frequencyHz    = [dictionary floatForKey:@"Frequency"];
				jointDef.dampingRatio   = [dictionary floatForKey:@"Damping"];
				
				if(0 != boxWorld){
					joint = (b2DistanceJoint*)boxWorld->CreateJoint(&jointDef);
				}
			}	
				break;
				
			case LH_REVOLUTE_JOINT:
			{
				b2RevoluteJointDef jointDef;
				
				jointDef.lowerAngle     = CC_DEGREES_TO_RADIANS([dictionary floatForKey:@"LowerAngle"]);
				jointDef.upperAngle     = CC_DEGREES_TO_RADIANS([dictionary floatForKey:@"UpperAngle"]);
				jointDef.motorSpeed     = [dictionary floatForKey:@"MotorSpeed"];
				jointDef.maxMotorTorque = [dictionary floatForKey:@"MaxTorque"];
				jointDef.enableLimit    = [dictionary boolForKey:@"EnableLimit"];
				jointDef.enableMotor    = [dictionary boolForKey:@"EnableMotor"];
				jointDef.collideConnected = collideConnected;    
				
				jointDef.Initialize(bodyA, bodyB, posA);
				
				if(0 != boxWorld){
					joint = (b2RevoluteJoint*)boxWorld->CreateJoint(&jointDef);
				}
			}
				break;
				
			case LH_PRISMATIC_JOINT:
			{
				b2PrismaticJointDef jointDef;
				
				// Bouncy limit
				CGPoint axisPt = [dictionary pointForKey:@"Axis"];
				
				b2Vec2 axis(axisPt.x, axisPt.y);
				axis.Normalize();
				
				jointDef.Initialize(bodyA, bodyB, posA, axis);
				
				jointDef.motorSpeed     = [dictionary floatForKey:@"MotorSpeed"];
				jointDef.maxMotorForce  = [dictionary floatForKey:@"MaxMotorForce"];
				
				jointDef.lowerTranslation =  CC_DEGREES_TO_RADIANS([dictionary floatForKey:@"LowerTranslation"]);
				jointDef.upperTranslation = CC_DEGREES_TO_RADIANS([dictionary floatForKey:@"UpperTranslation"]);
				
				jointDef.enableMotor = [dictionary boolForKey:@"EnableMotor"];
				jointDef.enableLimit = [dictionary boolForKey:@"EnableLimit"];
				jointDef.collideConnected = collideConnected;   

				if(0 != boxWorld){
					joint = (b2PrismaticJoint*)boxWorld->CreateJoint(&jointDef);
				}
			}	
				break;
				
			case LH_PULLEY_JOINT:
			{
				b2PulleyJointDef jointDef;
				
				CGPoint grAnchorA = [dictionary pointForKey:@"GroundAnchorRelativeA"];
				CGPoint grAnchorB = [dictionary pointForKey:@"GroundAnchorRelativeB"];
				
                b2Vec2 bodyAPos = bodyA->GetPosition();
                b2Vec2 bodyBPos = bodyB->GetPosition();
                
				b2Vec2 groundAnchorA = b2Vec2(bodyAPos.x + convertX*grAnchorA.x/ptm, bodyAPos.y - grAnchorA.y/ptm);
				b2Vec2 groundAnchorB = b2Vec2(bodyBPos.x + convertX*grAnchorB.x/ptm, bodyBPos.y - grAnchorB.y/ptm);
				                                                    
				float ratio = [dictionary floatForKey:@"Ratio"];
				jointDef.Initialize(bodyA, bodyB, groundAnchorA, groundAnchorB, posA, posB, ratio);				
				jointDef.collideConnected = collideConnected;   
				
				if(0 != boxWorld){
					joint = (b2PulleyJoint*)boxWorld->CreateJoint(&jointDef);
				}
			}
				break;
				
			case LH_GEAR_JOINT:
			{
				b2GearJointDef jointDef;
				
				jointDef.bodyA = bodyB;
				jointDef.bodyB = bodyA;
				
				if(bodyA == 0)
					return;
				if(bodyB == 0)
					return;
				
                LHJoint* jointAObj  = [parentLoader jointWithUniqueName:[dictionary stringForKey:@"JointA"]];
                b2Joint* jointA     = [jointAObj joint];
                
                LHJoint* jointBObj  = [parentLoader jointWithUniqueName:[dictionary stringForKey:@"JointB"]];
                b2Joint* jointB     = [jointBObj joint];
                
				if(jointA == 0)
					return;
				if(jointB == 0)
					return;
				
				
				jointDef.joint1 = jointA;
				jointDef.joint2 = jointB;
				
				jointDef.ratio  = [dictionary floatForKey:@"Ratio"];
				jointDef.collideConnected = collideConnected;

				if(0 != boxWorld){
					joint = (b2GearJoint*)boxWorld->CreateJoint(&jointDef);
				}
			}	
				break;
				
				
			case LH_WHEEL_JOINT: //aka line joint
			{
#ifdef B2_WHEEL_JOINT_H
				b2WheelJointDef jointDef;
				
				CGPoint axisPt = [dictionary pointForKey:@"Axis"];
				b2Vec2 axis(axisPt.x, axisPt.y);
				axis.Normalize();
				
				jointDef.motorSpeed     = [dictionary floatForKey:@"MotorSpeed"];
				jointDef.maxMotorTorque = [dictionary floatForKey:@"MaxTorque"];
				jointDef.enableMotor    = [dictionary floatForKey:@"EnableMotor"];
				jointDef.frequencyHz    = [dictionary floatForKey:@"Frequency"];
				jointDef.dampingRatio   = [dictionary floatForKey:@"Damping"];
				
				jointDef.Initialize(bodyA, bodyB, posA, axis);
				jointDef.collideConnected = collideConnected; 
				
				if(0 != boxWorld){
					joint = (b2WheelJoint*)boxWorld->CreateJoint(&jointDef);
				}
#endif
			}
				break;				
			case LH_WELD_JOINT:
			{
				b2WeldJointDef jointDef;
				
//we use this define because this is only in latest box2d and since the library does not have a compile time versioning system this is the only way
#ifdef B2_WHEEL_JOINT_H 
				jointDef.frequencyHz    = [dictionary floatForKey:@"Frequency"];
				jointDef.dampingRatio   = [dictionary floatForKey:@"Damping"];
#endif				
				jointDef.Initialize(bodyA, bodyB, posA);
				jointDef.collideConnected = collideConnected; 
				
				if(0 != boxWorld){
					joint = (b2WeldJoint*)boxWorld->CreateJoint(&jointDef);
				}
			}
				break;
				
			case LH_ROPE_JOINT:
			{
#ifdef B2_ROPE_JOINT_H
				b2RopeJointDef jointDef;
				
                jointDef.localAnchorA = b2Vec2(bodyA->GetLocalCenter().x + (anchorA.x*scaleA.width/ptm),
                                            bodyA->GetLocalCenter().y - (anchorA.y*scaleA.height/ptm));

                jointDef.localAnchorB = b2Vec2(bodyB->GetLocalCenter().x + (anchorB.x*scaleB.width/ptm),
                                            bodyB->GetLocalCenter().y - (anchorB.y*scaleB.height/ptm));

				jointDef.bodyA = bodyA;
				jointDef.bodyB = bodyB;
				float length = [dictionary floatForKey:@"MaxLength"];
                
                if(length <= 0)
                    length = 0.01;
                
                jointDef.maxLength = (bodyA->GetWorldPoint(posA) - bodyB->GetWorldPoint(posB)).Length() * length;

				jointDef.collideConnected = collideConnected;
				
				if(0 != boxWorld){
					joint = (b2RopeJoint*)boxWorld->CreateJoint(&jointDef);

                    [self prepareRopeJointsWithDictionary:dictionary];
				}
#endif
			}

				break;
				
			case LH_FRICTION_JOINT:
			{
				b2FrictionJointDef jointDef;
				
				jointDef.maxForce   = [dictionary floatForKey:@"MaxForce"];
				jointDef.maxTorque  = [dictionary floatForKey:@"MaxTorque"];
				
				jointDef.Initialize(bodyA, bodyB, posA);
				jointDef.collideConnected = collideConnected; 
				
				if(0 != boxWorld){
					joint = (b2FrictionJoint*)boxWorld->CreateJoint(&jointDef);
				}
				
			}
				break;
				
			default:
				NSLog(@"Unknown joint type in LevelHelper file.");
				break;
		}
	}
    
   
#ifndef LH_ARC_ENABLED
    joint->SetUserData(self);
#else
    joint->SetUserData((__bridge void*)self);
#endif
}

#ifdef B2_ROPE_JOINT_H
-(void)prepareRopeJointsWithDictionary:(NSDictionary*)dictionary
{
    rope_showRepresentation = false;
    rope_textureName = @"";
    rope_z = 0;
    
    if([dictionary boolForKey:@"ShowRepresentation"])
    {
        rope_showRepresentation = true;
        if([dictionary objectForKey:@"TextureName"])
        {
            NSString* texture = [dictionary objectForKey:@"TextureName"];
            texture = [texture lastPathComponent];
            
            rope_textureName = [[NSString alloc] initWithString:texture];
            
            if([dictionary objectForKey:@"SegmentsFactor"]){
                rope_segmentFactor = [dictionary intForKey:@"SegmentsFactor"];
            }
            else{
                rope_segmentFactor = 12;
            }
            
            rope_spriteSheet = [CCSpriteBatchNode batchNodeWithFile:texture];
            
            if(rope_spriteSheet){
                LHLayer* layer  = [parentLoader layerWithUniqueName:@"MAIN_LAYER"];
                if(layer){
                    if([dictionary objectForKey:@"RepresentationZ"]){
                        rope_z = [dictionary intForKey:@"RepresentationZ"];
                        
                    }
                    [layer addChild:rope_spriteSheet z:rope_z];
                    
                    rope_points = [[NSMutableArray alloc] init];
                    rope_sticks = [[NSMutableArray alloc] init];
                    rope_sprites = [[NSMutableArray alloc] init];
                    
                    [self createRopeJointRepresentation];
                    [self scheduleUpdate];
                    
                    [layer addChild:self];
                }
            }
        }
        else{
            NSLog(@"Rope texture \"%@\" does not have a texture but wants visual representation", uniqueName);
        }
    }
}


-(void)updateRopePointsWithA:(CGPoint)pointA
                           B:(CGPoint)pointB
                          dt:(float)dt
{

    if([rope_points count] > 0){
        [(LHRopePoint*)[rope_points objectAtIndex:0] setPosition:pointA];
        [(LHRopePoint*)[rope_points objectAtIndex:rope_numPoints-1] setPosition:pointB];
	
        for(int i=1; i<rope_numPoints-1; ++i) {
            [(LHRopePoint*)[rope_points objectAtIndex:i] applyGravity:dt];
            [(LHRopePoint*)[rope_points objectAtIndex:i] update];
        }
	
        for(int j=0; j<4; ++j) {
            for(int i=0;i<rope_numPoints-1;++i) {
                [(LHRopeStick*)[rope_sticks objectAtIndex:i] contract];
            }
        }
    }
}

-(void)updateRopeSprites
{
	if(rope_spriteSheet)
    {
		for(int i=0;i<rope_numPoints-1;++i)
        {
			LHRopePoint *pointA = [[rope_sticks objectAtIndex:i] ropePointA];
            LHRopePoint *pointB = [[rope_sticks objectAtIndex:i] ropePointB];
            
			float stickAngle = ccpToAngle(ccpSub([pointA position],
                                                 [pointB position]));
			CCSprite *tmpSprite = [rope_sprites objectAtIndex:i];
			[tmpSprite setPosition:ccpMidpoint([pointA position],
                                               [pointB position])];
			[tmpSprite setRotation: -CC_RADIANS_TO_DEGREES(stickAngle)];
		}
	}
}

-(void)update:(ccTime)dt{
    
    if(LH_ROPE_JOINT == [LHJoint typeFromBox2dJoint:joint])
    {
        CGPoint pointA = [LevelHelperLoader metersToPoints:joint->GetAnchorA()];
        CGPoint pointB = [LevelHelperLoader metersToPoints:joint->GetAnchorB()];
        [self updateRopePointsWithA:pointA
                                  B:pointB
                                 dt:dt];
        [self updateRopeSprites];
    }
}

-(void)createRopeJointRepresentation
{
    float ptm = [[LHSettings sharedInstance] lhPtmRatio];
    
    CGPoint pointA  = [LevelHelperLoader metersToPoints:joint->GetAnchorA()];
    CGPoint pointB  = [LevelHelperLoader metersToPoints:joint->GetAnchorB()];
    float length    = ((b2RopeJoint*)joint)->GetMaxLength()*ptm;

    [rope_points removeAllObjects];
    [rope_sticks removeAllObjects];
    for(CCSprite* spr in rope_sprites){
        [spr removeFromParentAndCleanup:YES];
    }
    [rope_sprites removeAllObjects];
    
    rope_numPoints = length/rope_segmentFactor;
    
	CGPoint diffVector = ccpSub(pointB,pointA);
	float multiplier = length / (rope_numPoints-1);
    
	antiSagHack = 0.1f; //HACK: scale down rope points to cheat sag. set to 0 to disable, max suggested value 0.1
	
    for(int i=0; i<rope_numPoints; ++i)
    {
		CGPoint tmpPos = ccpAdd(pointA, ccpMult(ccpNormalize(diffVector),multiplier*i*(1-antiSagHack)));
        LHRopePoint* rpPoint = [LHRopePoint ropePoint];
        [rpPoint setPosition:tmpPos];
		[rope_points addObject:rpPoint];
	}
	for(int i=0; i<rope_numPoints-1; ++i)
    {
        LHRopeStick* stick = [LHRopeStick ropeStickWithRopePointA:[rope_points objectAtIndex:i]
                                                       ropePointB:[rope_points objectAtIndex:i+1]];
        
        [rope_sticks addObject:stick];
	}
	
    if(rope_spriteSheet)
    {
		for(int i=0; i<rope_numPoints-1; ++i)
        {
			LHRopePoint *pointA = [[rope_sticks objectAtIndex:i] ropePointA];
            LHRopePoint *pointB = [[rope_sticks objectAtIndex:i] ropePointB];
			
			CGPoint stickVector = ccpSub([pointA position],[pointB position]);
			float stickAngle = ccpToAngle(stickVector);
			CCSprite *tmpSprite = [CCSprite spriteWithTexture:rope_spriteSheet.texture
                                                         rect:CGRectMake(0,0,
                                                                         multiplier,
                                                                         [[[rope_spriteSheet textureAtlas] texture] pixelsHigh]/CC_CONTENT_SCALE_FACTOR())];
			ccTexParams params = {GL_LINEAR,GL_LINEAR,GL_REPEAT,GL_REPEAT};
			[tmpSprite.texture setTexParameters:&params];
			[tmpSprite setPosition:ccpMidpoint([pointA position],[pointB position])];
			[tmpSprite setRotation:-1 * CC_RADIANS_TO_DEGREES(stickAngle)];
			[rope_spriteSheet addChild:tmpSprite];
            [rope_sprites addObject:tmpSprite];
		}
	}
}



- (BOOL)checkLineIntersection:(CGPoint)p1 :(CGPoint)p2 :(CGPoint)p3 :(CGPoint)p4
{
    // http://local.wasp.uwa.edu.au/~pbourke/geometry/lineline2d/
    CGFloat denominator = (p4.y - p3.y) * (p2.x - p1.x) - (p4.x - p3.x) * (p2.y - p1.y);
    
    // In this case the lines are parallel so we assume they don't intersect
    if (denominator == 0.0f)
        return NO;
    CGFloat ua = ((p4.x - p3.x) * (p1.y - p3.y) - (p4.y - p3.y) * (p1.x - p3.x)) / denominator;
    CGFloat ub = ((p2.x - p1.x) * (p1.y - p3.y) - (p2.y - p1.y) * (p1.x - p3.x)) / denominator;
    
    if (ua >= 0.0 && ua <= 1.0 && ub >= 0.0 && ub <= 1.0)
    {
        return YES;
    }
    
    return NO;
}



-(b2Body *) createTipBody{
    b2BodyDef bodyDef;
    bodyDef.type = b2_dynamicBody;
    bodyDef.linearDamping = 0.5f;
    b2World* world = joint->GetBodyA()->GetWorld();
    if(world){
        b2Body *body = world->CreateBody(&bodyDef);
        b2FixtureDef circleDef;
        b2CircleShape circle;

        float ptm = [[LHSettings sharedInstance] lhPtmRatio];
        circle.m_radius =  1.0/ptm;
        circleDef.shape = &circle;
        circleDef.density = 10.0f;
         
        // Since these tips don't have to collide with anything
        // set the mask bits to zero
//        circleDef.filter.maskBits = 0;
        body->CreateFixture(&circleDef);
         
        return body;
    }
    return NULL;
}

-(void)resetRopeJoint {
	CGPoint pointA = [LevelHelperLoader metersToPoints:joint->GetAnchorA()];
	CGPoint pointB = [LevelHelperLoader metersToPoints:joint->GetAnchorB()];
	[self resetWithPoints:pointA pointB:pointB];
}

-(bool)ropeWasCut{
    return rope_wasCut;
}

-(void)resetWithPoints:(CGPoint)pointA pointB:(CGPoint)pointB {
	float distance = ccpDistance(pointA,pointB);
	CGPoint diffVector = ccpSub(pointB,pointA);
	float multiplier = distance / (rope_numPoints - 1);
	for(int i=0;i<rope_numPoints;++i) {
		CGPoint tmpVector = ccpAdd(pointA, ccpMult(ccpNormalize(diffVector),multiplier*i*(1-antiSagHack)));
		LHRopePoint *tmpPoint = [rope_points objectAtIndex:i];
        [tmpPoint setPosition:tmpVector];
	}
}

-(bool)cutRopeAtStick:(LHRopeStick *)stick
                  newBodyA:(b2Body*)newBodyA
                  newBodyB:(b2Body*)newBodyB
{    
    // Find out where the rope will be cut
    int nPoint = [rope_sticks indexOfObject:stick];
    
    // Position the new dummy bodies
    LHRopePoint *pointOfBreak = [rope_points objectAtIndex:nPoint];
    b2Vec2 newBodiesPosition = [LevelHelperLoader pointsToMeters:[pointOfBreak position]];
    newBodyA->SetTransform(newBodiesPosition, 0.0);
    newBodyB->SetTransform(newBodiesPosition, 0.0);

    // Get a reference to the world to create the new joint
    b2World *world = joint->GetBodyA()->GetWorld();
    
    // This will determine how long the rope is now and how long the new rope will be
    float32 cutRatio = (float32)nPoint / (rope_numPoints - 1);

    // Re-create the joint
    b2RopeJointDef jd;
    jd.bodyA = joint->GetBodyA();
    jd.bodyB = newBodyB;
    jd.localAnchorA = ((b2RopeJoint*)joint)->GetLocalAnchorA();
    jd.localAnchorB = b2Vec2(0, 0);
    jd.maxLength = ((b2RopeJoint*)joint)->GetMaxLength() * cutRatio;
    b2RopeJoint *newJoint1 = (b2RopeJoint *)world->CreateJoint(&jd); //create joint

    
    
    // Create the new rope joint
    jd.bodyA = newBodyA;
    jd.bodyB = joint->GetBodyB();
    jd.localAnchorA = b2Vec2(0, 0);
    jd.localAnchorB = ((b2RopeJoint*)joint)->GetLocalAnchorB();
    jd.maxLength = ((b2RopeJoint*)joint)->GetMaxLength() * (1 - cutRatio);
    b2RopeJoint *newJoint2 = (b2RopeJoint *)world->CreateJoint(&jd); //create joint

    
    

    // Destroy the old joint and update to the new one
    world->DestroyJoint(joint);
    joint = newJoint1;
    
    rope_wasCut = true;
#ifndef LH_ARC_ENABLED
    joint->SetUserData(self);
#else
    joint->SetUserData((__bridge void*)self);
#endif

    
    
    NSMutableDictionary* dictionary = [NSMutableDictionary dictionary];
    [dictionary setObject:[NSNumber numberWithBool:rope_showRepresentation]
                   forKey:@"ShowRepresentation"];
    if(rope_textureName){
        [dictionary setObject:rope_textureName
                       forKey:@"TextureName"];
    }
    [dictionary setObject:[NSString stringWithFormat:@"%@1", uniqueName]
                   forKey:@"UniqueName"];
    
    [dictionary setObject:[NSNumber numberWithInt:rope_segmentFactor]
                   forKey:@"SegmentsFactor"];
    
    [dictionary setObject:[NSNumber numberWithInt:rope_z]
                   forKey:@"RepresentationZ"];
    
    
    LHJoint* newLhJoint = [LHJoint ropeJointWithDictionary:dictionary
                                                     joint:newJoint2
                                                    loader:parentLoader];
    if(newLhJoint){
        [newLhJoint setTag:tag];
        [parentLoader addJoint:newLhJoint];
    }

    
    
    
    [self createRopeJointRepresentation];
    
    
    
    return true;
}





-(bool)cutRopeJointsIntesectingWithLineFromPointA:(CGPoint)a
                                         toPointB:(CGPoint)b{
    
    if([self type] != LH_ROPE_JOINT)return false;
    
    for(LHRopeStick* stick in rope_sticks)
    {
        CGPoint pa = [[stick ropePointA] position];
        CGPoint pb = [[stick ropePointB] position];
        
        if([self checkLineIntersection:a :b :pa :pb])
        {

            b2Body *newBodyA = [self createTipBody];
            b2Body *newBodyB = [self createTipBody];
            
            [self cutRopeAtStick:stick
                        newBodyA:newBodyA
                        newBodyB:newBodyB];
            
            return YES;
        }
    }
    return NO;
}
#endif

//------------------------------------------------------------------------------
+(bool) isLHJoint:(id)object{   
    if([object isKindOfClass:[LHJoint class]]){
        return true;
    }
    return false;
}
//------------------------------------------------------------------------------
+(LHJoint*) jointFromBox2dJoint:(b2Joint*)jt{    
    if(jt == NULL) return NULL;
    
#ifndef LH_ARC_ENABLED
    id lhJt = (id)jt->GetUserData();
#else
    id lhJt = (__bridge id)jt->GetUserData();
#endif
    
    if([LHJoint isLHJoint:lhJt]){
        return (LHJoint*)lhJt;
    }
    
    return NULL;    
}
//------------------------------------------------------------------------------
+(int) tagFromBox2dJoint:(b2Joint*)joint{
    if(0 != joint){
#ifndef LH_ARC_ENABLED
        LHJoint* data = (LHJoint*)joint->GetUserData();
#else
        LHJoint* data = (__bridge LHJoint*)joint->GetUserData();
#endif
        if(nil != data)return [data tag];
    }
    return -1;
}
//------------------------------------------------------------------------------
+(enum LH_JOINT_TYPE) typeFromBox2dJoint:(b2Joint*)joint{
    if(0 != joint){
#ifndef LH_ARC_ENABLED
        LHJoint* data = (LHJoint*)joint->GetUserData();
#else
        LHJoint* data = (__bridge LHJoint*)joint->GetUserData();
#endif
        if(nil != data) return [data type];
    }
    return LH_UNKNOWN_TYPE;    
}
//------------------------------------------------------------------------------
+(NSString*) uniqueNameFromBox2dJoint:(b2Joint*)joint{
    if(0 != joint){
#ifndef LH_ARC_ENABLED
        LHJoint* data = (LHJoint*)joint->GetUserData();
#else
        LHJoint* data = (__bridge LHJoint*)joint->GetUserData();
#endif
        if(0 != data)return [data uniqueName];
    }
    return nil;
}

@end
#endif
