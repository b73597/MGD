//
//  GameScene.m
//  FutBoy
//
//  Created by Omar Davila on 7/6/15.
//  Copyright (c) 2015 Omar Davila. All rights reserved.
//

#import "GameScene.h"
#import "FutBoyChar.h"

#define kLastUpdatedNone 0

#define kShootButton @"SHOOT_BTN"
#define kANIMPlayerRunning @"running_anim"

#define kMovingAnimation 0.033
#define kBallAnimation 0.1
#define kCryingAnimation 0.5
#define kShootAnimation 0.05

//player can run 0.3 height each second
#define kPlayerRunSpeed 0.3

#define kBottomLine 0.2

enum EGameState{
    STATE_IDLE = 0,
    STATE_MOVING,
    STATE_SHOOTING,
    STATE_FINISH
};

@interface GameScene()
{
    CFTimeInterval lastUpdated;
    enum EGameState state;
    CGPoint targetLocation;
    CGFloat ballSpeedX, ballSpeedY, gravity;
}
@property(strong)    SKSpriteNode* player;
@property(strong)    SKSpriteNode* ball;
@property(strong)    NSMutableArray* defenders;
@property(strong)    SKTextureAtlas *atlas;

@property(strong)    SKAction* playerRunAction;
@property(strong)    SKAction* playSoundKick;
@property(strong)    SKAction* playSoundStart;

@end

@implementation GameScene

-(void)didMoveToView:(SKView *)view {
    /* Setup your scene here */
    srand(time(NULL));
    // load atlas explicitly, to avoid frame rate drop in new animations
    self.atlas = [SKTextureAtlas atlasNamed:CHARACTER_ATLAS_NAME];
    
    
    
    // load background image
    SKSpriteNode *background = [SKSpriteNode spriteNodeWithTexture:CHARACTER_TEX_BACKGROUND];
    background.anchorPoint = CGPointMake(0, 0);
    background.size = self.frame.size;
    [self addChild: background];

    
    // load btn image
    SKSpriteNode *shootBtn = [SKSpriteNode spriteNodeWithTexture:CHARACTER_TEX_BUTTONS_CONTROLS_SHOOTBUTTONSPRITE];
    shootBtn.name = kShootButton;
    shootBtn.position = CGPointMake(900,58);
    shootBtn.xScale = 3.0;
    shootBtn.yScale = 3.0;
    [self addChild: shootBtn];
    
    // load sprites
    self.player = [SKSpriteNode spriteNodeWithTexture:CHARACTER_TEX_RUNANIMATION_RUN_2];
    self.player.xScale = self.player.yScale = 2.0;
    self.player.position = CGPointMake(200, 200);
    [self addChild:self.player];

    self.ball = [SKSpriteNode spriteNodeWithTexture:CHARACTER_TEX_BALLANIMATION_BALL_0];
    self.ball.xScale = self.ball.yScale = 1.5;
    [self addChild:self.ball];
    
    //set up actions to move and animate to "tap" location
    SKAction* ballMovingAnimation = [SKAction animateWithTextures:CHARACTER_ANIM_BALLANIMATION_BALL timePerFrame:kMovingAnimation];
    [self.ball runAction:[SKAction repeatActionForever:ballMovingAnimation]];

    self.playerRunAction = [SKAction repeatActionForever:[SKAction animateWithTextures:CHARACTER_ANIM_RUNANIMATION_RUN timePerFrame:kMovingAnimation]];
    
    self.defenders = [[NSMutableArray alloc] init];
    
    self.playSoundKick = [SKAction playSoundFileNamed:@"kick.mp3" waitForCompletion:NO];
    self.playSoundStart = [SKAction playSoundFileNamed:@"start.mp3" waitForCompletion:NO];
    [self reset];
}
-(void)reset
{
    lastUpdated = kLastUpdatedNone;
    state = STATE_IDLE;
    gravity = -self.frame.size.height * 0.8;
    ballSpeedX = self.frame.size.width / 4;
    ballSpeedY = 0;
    [self.player removeAllActions];
    [self playerSetIDLE];
    self.ball.position = [self ballLocationForPlayerLocation:self.player.position];
    for(SKSpriteNode* node in self.defenders) [node removeFromParent];
    [self.defenders removeAllObjects];
    for(int i=0;i<3;i++){
        [self.defenders addObject:[self createDefenderAtOffset:(0.5+.3*i/2)*self.frame.size.width]];
    }
    [self runAction:self.playSoundStart];
}
-(CGPoint)ballLocationForPlayerLocation: (CGPoint)loc
{
    return CGPointMake(loc.x+self.player.frame.size.width*.6, loc.y-self.player.frame.size.height*.3);
}
-(SKSpriteNode*)createDefenderAtOffset: (CGFloat)x
{
    SKSpriteNode* defender = [SKSpriteNode spriteNodeWithTexture:CHARACTER_TEX_SHOOTANIMATION_SHOOT_0];
    defender.anchorPoint = CGPointMake(.5, .5);
    defender.position = CGPointMake(x, self.frame.size.height*.5);
    defender.xScale = -2; defender.yScale = 2;
    [self addChild:defender];
    
    SKAction* defenderMovingAnimation = [SKAction animateWithTextures:CHARACTER_ANIM_RUNANIMATION_RUN timePerFrame:kBallAnimation];
    SKAction* defenderMoving = [self createRandomMovementSequenceForDefenderFromY:self.frame.size.height-defender.size.height toY:defender.size.height withCount:3+(rand()%4)];
                                
    [defender runAction:[SKAction repeatActionForever:defenderMovingAnimation]];
    [defender runAction:[SKAction repeatActionForever:defenderMoving]];
    return defender;
}

-(SKAction*) createRandomMovementSequenceForDefenderFromY: (CGFloat)fromY toY: (CGFloat)toY withCount: (int)count
{
    NSMutableArray* moveArray = [[NSMutableArray alloc] init];
    for(int i=0;i<count;i++){
        double movingTime = 1.5+(.5*(rand()%1000)/1000);
        SKAction* defenderMoving1 = [SKAction moveToY:fromY duration:movingTime];
        SKAction* defenderMoving2 = [SKAction moveToY:toY duration:movingTime];
        [moveArray addObject:defenderMoving1];
        [moveArray addObject:defenderMoving2];
    }
    return [SKAction sequence:moveArray];
}

-(void)playerSetIDLE
{
    if(state==STATE_MOVING) state = STATE_IDLE;
    [self.player removeActionForKey:kANIMPlayerRunning];
    self.player.texture = CHARACTER_TEX_RUNANIMATION_RUN_2;
}

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if(state >= STATE_SHOOTING){
        return;
    }
    UITouch* touch = [touches anyObject];
    targetLocation = [touch locationInNode:self];
    SKNode *node = [self nodeAtPoint:targetLocation];
    if([node.name isEqualToString:kShootButton]){
        [self runAction:self.playSoundKick];
        state = STATE_SHOOTING;
        [self.player runAction:[SKAction animateWithTextures:CHARACTER_ANIM_SHOOTANIMATION_SHOOT timePerFrame:kShootAnimation]];
    }
    if(state >= STATE_MOVING) return;
    state = STATE_MOVING;
    [self.player runAction:self.playerRunAction withKey:kANIMPlayerRunning];
    
}

-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch* touch = [touches anyObject];
    targetLocation = [touch locationInNode:self];
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if(state == STATE_FINISH){
        UITouch* touch = [touches anyObject];
        targetLocation = [touch locationInNode:self];
        SKNode *node = [self nodeAtPoint:targetLocation];
        if([node.name isEqualToString:kShootButton]){
            [self reset];
            return;
        }
    }else{
        [self playerSetIDLE];
    }
}

-(void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self playerSetIDLE];
}

-(void)update:(CFTimeInterval)currentTime {
    if(state == STATE_SHOOTING){
        if(lastUpdated!=kLastUpdatedNone){
            self.ball.position = CGPointMake(self.ball.position.x + ballSpeedX * (currentTime-lastUpdated), self.ball.position.y + ballSpeedY * (lastUpdated-currentTime));
            ballSpeedY -= gravity * (currentTime-lastUpdated);
            if(self.ball.position.y < self.frame.size.height * kBottomLine){
                ballSpeedY = -ballSpeedY;
            }
            BOOL isWin = NO;
            for(SKSpriteNode* def in self.defenders){
                if(ABS(def.position.x-self.ball.position.x)<def.size.width/2 &&
                   ABS(def.position.y-self.ball.position.y)<def.size.height/2){
                    state = STATE_FINISH;
                    [self.player removeAllActions];
                    [self.player runAction:[SKAction repeatActionForever:[SKAction animateWithTextures:CHARACTER_ANIM_CRYANIMATION_CRY timePerFrame:kCryingAnimation]]];
                    isWin = NO;
                    break;
                }
            }
            if(state < STATE_FINISH){
                if(self.ball.position.x >= self.frame.size.width*.95){
                    state = STATE_FINISH;
                    isWin = YES;
                    [self.player removeAllActions];
                    [self.player runAction:[SKAction repeatActionForever:[SKAction animateWithTextures:CHARACTER_ANIM_SHOOTANIMATION_SHOOT timePerFrame:kShootAnimation]]];
                }
            }
            if(state == STATE_FINISH){
                for(SKSpriteNode* def in self.defenders){
                    [def removeAllActions];
                    if(!isWin){
                        [def runAction:[SKAction repeatActionForever:[SKAction animateWithTextures:CHARACTER_ANIM_SHOOTANIMATION_SHOOT timePerFrame:kShootAnimation]]];
                    }else{
                        [def runAction:[SKAction repeatActionForever:[SKAction animateWithTextures:CHARACTER_ANIM_CRYANIMATION_CRY timePerFrame:kCryingAnimation]]];
                    }
                }
            }
        }
    } else if(state == STATE_MOVING){
        //smooth movement
        CGFloat delta = 0.1;
        if(lastUpdated!=kLastUpdatedNone){
            delta = (currentTime-lastUpdated);
        }
        CGPoint newPosition = CGPointMake(
                                         targetLocation.x*delta+self.player.position.x*(1.-delta),
                                         targetLocation.y*delta+self.player.position.y*(1.-delta)
                                         );
        newPosition.x = MAX(MIN(newPosition.x,self.frame.size.width*.35),self.frame.size.width*.1);
        newPosition.y = MAX(newPosition.y,kBottomLine*self.frame.size.height+self.player.size.height*.5);
        self.player.position = newPosition;
        self.ball.position = [self ballLocationForPlayerLocation:self.player.position];
    }
    lastUpdated = currentTime;
}

@end
