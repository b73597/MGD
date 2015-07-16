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
#define kPauseButton @"PAUSE_BTN"
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

enum ECollider{
    COL_PLAYER = 1,
    COL_ENEMY  = 2
};

@interface GameScene()
{
    CFTimeInterval lastUpdated, pausingStart;
    enum EGameState state;
    CGPoint targetLocation;
    CGFloat ballSpeedX, ballSpeedY, gravity;
    
    int nScore, nShoots;
    BOOL isPausing;
}
@property(strong)    SKSpriteNode* player;
@property(strong)    SKSpriteNode* ball;
@property(strong)    NSMutableArray* defenders;
@property(strong)    SKTextureAtlas *atlas;

@property(strong)   SKLabelNode* scoreLabel;
@property(strong)   SKLabelNode* pauseBtn;

@property(strong)    SKAction* playerRunAction;
@property(strong)    SKAction* playSoundKick;
@property(strong)    SKAction* playSoundStart;

@end

@implementation GameScene

-(void)didMoveToView:(SKView *)view {
    /* Setup your scene here */
    srand(time(NULL));
    self.physicsWorld.gravity = CGVectorMake(0,0);
    self.physicsWorld.contactDelegate = self;
    
    // load atlas explicitly, to avoid frame rate drop in new animations
    self.atlas = [SKTextureAtlas atlasNamed:CHARACTER_ATLAS_NAME];
    
    nScore = 0; nShoots = 0;
    isPausing = NO;
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
    
    self.scoreLabel = [[SKLabelNode alloc] init];
    self.scoreLabel.position = CGPointMake(10, 10);
    self.scoreLabel.horizontalAlignmentMode = SKLabelHorizontalAlignmentModeLeft;
    self.scoreLabel.verticalAlignmentMode = SKLabelVerticalAlignmentModeBottom;
    [self addChild:self.scoreLabel];
    
    self.pauseBtn = [[SKLabelNode alloc] init];
    self.pauseBtn.position = CGPointMake(view.frame.size.width/2, 10);
    self.pauseBtn.horizontalAlignmentMode = SKLabelHorizontalAlignmentModeCenter;
    self.pauseBtn.verticalAlignmentMode = SKLabelVerticalAlignmentModeBottom;
    self.pauseBtn.name = kPauseButton;
    [self addChild:self.pauseBtn];
    
    // load sprites

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
    [self.player removeFromParent];
    self.player = [SKSpriteNode spriteNodeWithTexture:CHARACTER_TEX_RUNANIMATION_RUN_2];
    self.player.anchorPoint = CGPointMake(.5,.5);
    self.player.xScale = self.player.yScale = 2.0;
    self.player.position = CGPointMake(200, 200);
    
    self.player.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:CGSizeMake(self.player.size.width*.8,self.player.size.height*.9)];
    self.player.physicsBody.dynamic = YES;
    self.player.physicsBody.categoryBitMask = COL_PLAYER;
    self.player.physicsBody.collisionBitMask = 0;
    self.player.physicsBody.contactTestBitMask = COL_ENEMY;
    self.player.physicsBody.velocity = CGVectorMake(0, 0);
    //self.player.physicsBody.affectedByGravity = NO;
    self.player.physicsBody.usesPreciseCollisionDetection = YES;
    [self addChild:self.player];
    
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
    [self updateScore];
    [self updatePauseBtn];
}
-(void)updateScore
{
    self.scoreLabel.text = [NSString stringWithFormat:@"%d / %d",nScore,nShoots,nil];
}
-(void)updatePauseStateForNode: (SKView*)node status:(BOOL)isPaused
{
    for(SKView* child in node.subviews){
        [self updatePauseStateForNode:child status:isPaused];
    }
    if([node respondsToSelector:@selector(setPaused:)])
        node.paused = isPaused;
}
-(void)updatePauseBtn
{
    if(isPausing) self.pauseBtn.text = @"Resume";
    else self.pauseBtn.text = @"Pause";
    if(isPausing!=self.view.paused){
        if(isPausing){
            [self.pauseBtn runAction:[SKAction runBlock:^(){ [self updatePauseStateForNode: self.view status:YES]; }]];
        }else{
            lastUpdated = kLastUpdatedNone;
            [self updatePauseStateForNode: self.view status:NO];
        }
    }
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
    defender.xScale = 2; defender.yScale = 2;
    defender.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:CGSizeMake(defender.size.width*.8,defender.size.height*.9)];
    defender.xScale = -2;
    defender.physicsBody.dynamic = YES;
    defender.physicsBody.categoryBitMask = COL_ENEMY;
    defender.physicsBody.collisionBitMask = 0;
    defender.physicsBody.contactTestBitMask = COL_PLAYER;
    defender.physicsBody.usesPreciseCollisionDetection = YES;
    defender.speed = .2+.2*(rand()%1000)/1000;
    defender.physicsBody.velocity = CGVectorMake(0, self.frame.size.height * defender.speed);
    [self addChild:defender];
    
    SKAction* defenderMovingAnimation = [SKAction animateWithTextures:CHARACTER_ANIM_RUNANIMATION_RUN timePerFrame:kBallAnimation];
    
    [defender runAction:[SKAction repeatActionForever:defenderMovingAnimation]];
    return defender;
}

-(void)playerSetIDLE
{
    if(state==STATE_MOVING) state = STATE_IDLE;
    self.player.physicsBody.velocity = CGVectorMake(0, 0);
    [self.player removeActionForKey:kANIMPlayerRunning];
    self.player.texture = CHARACTER_TEX_RUNANIMATION_RUN_2;
}

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch* touch = [touches anyObject];
    targetLocation = [touch locationInNode:self];
    SKNode *node = [self nodeAtPoint:targetLocation];
    if([node.name isEqualToString:kPauseButton]){
        isPausing = !isPausing;
        [self updatePauseBtn];
        return;
    }
    if(isPausing || state >= STATE_SHOOTING){
        return;
    }
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
-(void)didBeginContact:(SKPhysicsContact *)contact
{
    if(!isPausing && state < STATE_SHOOTING){
        state = STATE_FINISH;
        self.player.physicsBody.velocity = CGVectorMake(0, 0);
        [self.player runAction:[SKAction repeatActionForever:[SKAction animateWithTextures:CHARACTER_ANIM_CRYANIMATION_CRY timePerFrame:kCryingAnimation]]];
        [self endGame:NO];
    }
}
-(void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self playerSetIDLE];
}
-(void)endGame: (BOOL)isWin
{
    nShoots ++;
    if(isWin) nScore++;
    for(SKSpriteNode* def in self.defenders){
        [def removeAllActions];
        def.physicsBody.velocity = CGVectorMake(0, 0);
        if(!isWin){
            [def runAction:[SKAction repeatActionForever:[SKAction animateWithTextures:CHARACTER_ANIM_SHOOTANIMATION_SHOOT timePerFrame:kShootAnimation]]];
        }else{
            [def runAction:[SKAction repeatActionForever:[SKAction animateWithTextures:CHARACTER_ANIM_CRYANIMATION_CRY timePerFrame:kCryingAnimation]]];
        }
    }
    [self updateScore];
}
-(void)update:(CFTimeInterval)currentTime {
    if(state < STATE_FINISH){
        for(SKNode* defender in self.defenders){
            if(defender.position.y <= self.frame.size.height*.2) defender.physicsBody.velocity = CGVectorMake(0, self.frame.size.height * defender.speed);
            else if(defender.position.y >= self.frame.size.height*.9) defender.physicsBody.velocity = CGVectorMake(0, -self.frame.size.height * defender.speed);
        }
    }
    if(state == STATE_SHOOTING){
        if(lastUpdated!=kLastUpdatedNone){
            self.ball.position = CGPointMake(self.ball.position.x + ballSpeedX * (currentTime-lastUpdated), self.ball.position.y + ballSpeedY * (lastUpdated-currentTime));
            ballSpeedY -= gravity * (currentTime-lastUpdated);
            if(self.ball.position.y < self.frame.size.height * kBottomLine){
                ballSpeedY = -ballSpeedY;
            }
            BOOL isWin = NO;
            enum EGameState oldState = state;
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
                    //[self.player runAction:[SKAction repeatActionForever:[SKAction animateWithTextures:CHARACTER_ANIM_SHOOTANIMATION_SHOOT timePerFrame:kShootAnimation]]];
                }
            }
            if(oldState!=state && state == STATE_FINISH){
                [self endGame:isWin];
            }
        }
    } else if(state == STATE_MOVING){
        self.player.physicsBody.velocity = CGVectorMake(targetLocation.x-self.player.position.x, targetLocation.y-self.player.position.y);
        self.ball.position = [self ballLocationForPlayerLocation:self.player.position];
    }
    lastUpdated = currentTime;
}

@end
