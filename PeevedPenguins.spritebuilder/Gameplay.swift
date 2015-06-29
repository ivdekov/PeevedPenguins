//
//  Gameplay.swift
//  PeevedPenguins
//
//  Created by Iavor Dekov on 6/26/15.
//  Copyright (c) 2015 Apportable. All rights reserved.
//

import UIKit

class Gameplay: CCNode, CCPhysicsCollisionDelegate {
   
    // member variables; code connections
    weak var gamePhysicsNode: CCPhysicsNode!
    weak var catapultArm: CCNode!
    weak var levelNode: CCNode!
    weak var contentNode: CCNode!
    weak var pullbackNode: CCNode!
    weak var mouseJointNode: CCNode!
    
    var mouseJoint: CCPhysicsJoint?
    var currentPenguin: Penguin?
    var penguinCatapultJoint: CCPhysicsJoint?
    var actionFollow: CCActionFollow?
    
    let minSpeed = CGFloat(5)
    
    // called when CCB file has completed loading
    func didLoadFromCCB() {
        userInteractionEnabled = true
        let level = CCBReader.load("Levels/Level1")
        levelNode.addChild(level)
        
        // nothing shall collide with our invisible nodes
        pullbackNode.physicsBody.collisionMask = []
        mouseJointNode.physicsBody.collisionMask = []
        
        gamePhysicsNode.collisionDelegate = self
        
        // visualize physics bodies and joints
        //gamePhysicsNode.debugDraw = true
        
    }
    
    func back() {
        let mainMenu = CCBReader.loadAsScene("MainScene")
        CCDirector.sharedDirector().presentScene(mainMenu)
    }
    
    func retry() {
        let gameplayScene = CCBReader.loadAsScene("Gameplay")
        CCDirector.sharedDirector().presentScene(gameplayScene)
    }
    
    // called on every touch in this scene
    override func touchBegan(touch: CCTouch!, withEvent event: CCTouchEvent!) {
        let touchLocation = touch.locationInNode(contentNode)
        
        // start catapult dragging when a touch inside of the catapult arm occurs
        if CGRectContainsPoint(catapultArm.boundingBox(), touchLocation) {
            
            // create a penguin from the ccb-file
            currentPenguin = CCBReader.load("Penguin") as! Penguin?
            if let currentPenguin = currentPenguin {
                // initially position it on the scoop. 34,138 is the position in the node space of the catapultArm
                let penguinPosition = catapultArm.convertToWorldSpace(CGPoint(x: 34, y: 138))
                // transform the world position to the node space to which the penguin will be added (gamePhysicsNode)
                currentPenguin.position = gamePhysicsNode.convertToNodeSpace(penguinPosition)
                // add it to the physics world
                gamePhysicsNode.addChild(currentPenguin)
                // we don't want the penguin to rotate in the scoop
                currentPenguin.physicsBody.allowsRotation = false
                
                // create a joint to keep the penguin fixed to the scoop until the catapult is released
                penguinCatapultJoint = CCPhysicsJoint.connectedPivotJointWithBodyA(currentPenguin.physicsBody, bodyB: catapultArm.physicsBody, anchorA: currentPenguin.anchorPointInPoints)
            }
        
            // move the mouseJointNode to the touch position
            mouseJointNode.position = touchLocation
            
            // setup a spring joint between the mouseJointNode and the catapultArm
            mouseJoint = CCPhysicsJoint.connectedSpringJointWithBodyA(mouseJointNode.physicsBody, bodyB: catapultArm.physicsBody, anchorA: CGPointZero, anchorB: CGPoint(x: 34, y: 138), restLength: 0, stiffness: 3000, damping: 150)
        }
    }
    
    override func touchMoved(touch: CCTouch!, withEvent event: CCTouchEvent!) {
        // whenever touches move, update the position of the mouseJointNode to the touch position
        let touchLocation = touch.locationInNode(contentNode)
        mouseJointNode.position = touchLocation
    }
    
    override func touchEnded(touch: CCTouch!, withEvent event: CCTouchEvent!) {
        // when touches end, meaning the user releases their finger, release the catapult
        //println("touch released")
        releaseCatapult()
    }
    
    override func touchCancelled(touch: CCTouch!, withEvent event: CCTouchEvent!) {
        // when touches are cancelled, meaning the user drags their finger off the screen or onto something else, release the catapult
        releaseCatapult()
    }
    
    func releaseCatapult() {
        if let joint = mouseJoint {
            // releases the joint and lets the catapult snap back
            joint.invalidate()
            mouseJoint = nil
            
            // releases the joint and lets the penguin fly
            penguinCatapultJoint?.invalidate()
            penguinCatapultJoint = nil
            
            currentPenguin?.launched = true
            
            // after snapping rotation is fine
            currentPenguin?.physicsBody.allowsRotation = true
            
            // follow the flying penguin
            actionFollow = CCActionFollow(target: currentPenguin, worldBoundary: boundingBox())
            contentNode.runAction(actionFollow)
        }
    }
    
    func launchPenguin() {
        // loads the Penguin.ccb we have set up in the SpriteBuilder
        let penguin = CCBReader.load("Penguin") as! Penguin
        
        // position the penguin at the bowl of the catapult
        penguin.position = ccpAdd(catapultArm.position, CGPoint(x: 16, y: 50))
        
        // add the penguin to the gamePhysicsNode (because the penguin has physics enabled)
        gamePhysicsNode.addChild(penguin)
        
        // manually create and apply a force to launch the penguin
        let launchDirection = CGPoint(x: 1, y: 0)
        let force = ccpMult(launchDirection, 8000)
        penguin.physicsBody.applyForce(force)
        
        // ensure followed object is in visible area when starting
        position = CGPoint.zeroPoint
        let actionFollow = CCActionFollow(target: penguin, worldBoundary: boundingBox())
        contentNode.runAction(actionFollow)
        
    }
    
    func ccPhysicsCollisionPostSolve(pair: CCPhysicsCollisionPair!, seal: Seal!, wildcard: CCNode!) {
        //println("Something collided with a seal!")
        
        let energy = pair.totalKineticEnergy
        
        // if energy is large enough, remove seal
        if energy > 5000 {
            gamePhysicsNode.space.addPostStepBlock({ () -> Void in self.sealRemoved(seal) }, key: seal)
        }
    }
    
    func sealRemoved(seal: Seal) {
        // load particle effect
        let explosion = CCBReader.load("SealExplosion") as! CCParticleSystem
        // make the particle effect clean itself up, once it is completed
        explosion.autoRemoveOnFinish = true;
        // place the particle effect on the seals position
        explosion.position = seal.position;
        // add the particle effect to the same node the seal is on
        seal.parent.addChild(explosion)
        // finally, remove the seal from the level
        seal.removeFromParent()
    }
    
    override func update(delta: CCTime) {
        if let currentPenguin = currentPenguin {
            if currentPenguin.launched {
            
                // if speed is below minimum speed, assume this attempt is over
                if ccpLength(currentPenguin.physicsBody.velocity) < minSpeed {
                    nextAttempt()
                    return
                }
                
                let xMin = currentPenguin.boundingBox().origin.x
                if (xMin < boundingBox().origin.x) {
                    nextAttempt()
                    return
                }
                
                let xMax = xMin + currentPenguin.boundingBox().size.width
                if xMax > (boundingBox().origin.x + boundingBox().size.width) {
                    nextAttempt()
                    return
                }
            }
        }
    }
    
    func nextAttempt() {
        currentPenguin = nil
        contentNode.stopAction(actionFollow)
        
        let actionMoveTo = CCActionMoveTo(duration: 1, position: CGPoint.zeroPoint)
        contentNode.runAction(actionMoveTo)
    }
    
}
