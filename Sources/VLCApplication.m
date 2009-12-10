/*****************************************************************************
 * VLCApplication.h:NSApplication subclass
 *****************************************************************************
 * Copyright (C) 2009 the VideoLAN team
 * $Id:$
 *
 * Authors:Felix Paul Kühne <fkuehne at videolan dot org>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/

#import <WebKit/WebKit.h>

#import <IOKit/hidsystem/ev_keymap.h>         /* for the media key support */

#import "VLCApplication.h"
#import "VLCStyledVideoWindowController.h"
#import "VLCMediaDocument.h"
#import "VLCDocumentController.h"

/*****************************************************************************
 * exclusively used to implement media key support on Al Apple keyboards
 *   b_justJumped is required as the keyboard send its events faster than
 *    the user can actually jump through his media
 *****************************************************************************/

@interface NSObject (RemoteResponder)
- (void)remoteMiddleButtonPressed:(id)sender;
- (void)remoteMenuButtonPressed:(id)sender;
- (void)remoteUpButtonPressed:(id)sender;
- (void)remoteDownButtonPressed:(id)sender;
- (void)remoteRightButtonPressed:(id)sender;
- (void)remoteLeftButtonPressed:(id)sender;
@end

@implementation VLCApplication

- (void)awakeFromNib
{
    // FIXME: -awakeFromNib is certainly not the right place to do the following
    WebPreferences *preferences = [WebPreferences standardPreferences];
    [preferences setCacheModel:WebCacheModelDocumentViewer];
    [preferences setPrivateBrowsingEnabled:YES];
    [preferences setUsesPageCache:NO];

    /* register our default values... */
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:@"YES", @"ControlWithMediaKeys", @"YES", @"ControlWithMediaKeysInBackground", @"YES", @"ControlWithHIDRemote", @"YES", @"UseDeinterlaceFilter", @"~/Desktop", @"SelectedSnapshotFolder", nil]];

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(coreChangedMediaKeySupportSetting:) name:@"NSUserDefaultsDidChangeNotification" object:nil];
    [center addObserver:self selector:@selector(applicationDidBecomeActiveOrInactive:) name:@"NSApplicationDidBecomeActiveNotification" object:nil];
    [center addObserver:self selector:@selector(applicationDidBecomeActiveOrInactive:) name:@"NSApplicationWillResignActiveNotification" object:nil];

    /* init Apple Remote support */
    _remote = [[AppleRemote alloc] init];
    [_remote setClickCountEnabledButtons:kRemoteButtonPlay];
    [_remote setListeningOnAppActivate:YES];
    [_remote setDelegate:self];

    [self coreChangedMediaKeySupportSetting:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_remote stopListening:self];
    [_remote release];
    [super dealloc];
}

#pragma mark -
#pragma mark Apple Remote Control

/* Helper method for the remote control interface in order to trigger forward/backward and volume
 increase/decrease as long as the user holds the left/right, plus/minus button */
- (void)executeHoldActionForRemoteButton:(NSNumber*) buttonIdentifierNumber
{
    if (_remoteButtonIsHold)
    {
        switch ([buttonIdentifierNumber intValue]) {
            case kRemoteButtonRight_Hold:
                [NSApp sendAction:@selector(remoteRightButtonPressed:) to:nil from:self];
                break;
            case kRemoteButtonLeft_Hold:
                [NSApp sendAction:@selector(remoteLeftButtonPressed:) to:nil from:self];
                break;
            case kRemoteButtonVolume_Plus_Hold:
                [NSApp sendAction:@selector(remoteUpButtonPressed:) to:nil from:self];
                break;
            case kRemoteButtonVolume_Minus_Hold:
                [NSApp sendAction:@selector(remoteDownButtonPressed:) to:nil from:self];
                break;
        }
        if (_remoteButtonIsHold) {
            /* trigger event */
            [self performSelector:@selector(executeHoldActionForRemoteButton:)
                       withObject:buttonIdentifierNumber
                       afterDelay:0.25];
        }
    }
}

/* Apple Remote callback */
- (void) appleRemoteButton:(AppleRemoteEventIdentifier)buttonIdentifier pressedDown:(BOOL)pressedDown clickCount:(unsigned int)count
{
    BOOL ret = NO;
    switch (buttonIdentifier)
    {
        case kRemoteButtonPlay:
            ret = [NSApp sendAction:@selector(remoteMiddleButtonPressed:) to:nil from:self];
            break;
        case kRemoteButtonMenu:
            ret = [NSApp sendAction:@selector(remoteMenuButtonPressed:) to:nil from:self];
            break;
        case kRemoteButtonVolume_Plus:
            ret = [NSApp sendAction:@selector(remoteUpButtonPressed:) to:nil from:self];
            break;
        case kRemoteButtonVolume_Minus:
            ret = [NSApp sendAction:@selector(remoteDownButtonPressed:) to:nil from:self];
            break;
        case kRemoteButtonRight:
            ret = [NSApp sendAction:@selector(remoteRightButtonPressed:) to:nil from:self];
            break;
        case kRemoteButtonLeft:
            ret = [NSApp sendAction:@selector(remoteLeftButtonPressed:) to:nil from:self];
            break;
        case kRemoteButtonRight_Hold:
        case kRemoteButtonLeft_Hold:
        case kRemoteButtonVolume_Plus_Hold:
        case kRemoteButtonVolume_Minus_Hold:
            /* simulate an event as long as the user holds the button */
            _remoteButtonIsHold = pressedDown;
            if (pressedDown) {
                NSNumber *buttonIdentifierNumber = [NSNumber numberWithInt:buttonIdentifier];
                [self performSelector:@selector(executeHoldActionForRemoteButton:)
                           withObject:buttonIdentifierNumber];
            }
            ret = YES; // FIXME?
            break;
        default:
            /* Add here whatever you want other buttons to do */
            break;
    }
    if (!ret)
        NSBeep();
}

- (void)applicationDidBecomeActiveOrInactive:(NSNotification *)notification
{
    BOOL hasResignedActive = [[notification name] isEqualToString:@"NSApplicationWillResignActiveNotification"];
    if ((hasResignedActive && !_isActiveInBackground ) || !_hasMediaKeySupport)
        _isActive = NO;
    else
        _isActive = YES;
}

- (void)coreChangedMediaKeySupportSetting:(NSNotification *)notification
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    _isActive = _hasMediaKeySupport = [defaults boolForKey:@"ControlWithMediaKeys"];
    _isActiveInBackground = [defaults boolForKey:@"ControlWithMediaKeysInBackground"];
    if ([defaults boolForKey:@"ControlWithHIDRemote"])
        [_remote startListening:self];
    else
        [_remote stopListening:self];
}


- (void)sendEvent:(NSEvent*)event
{
    if (_isActive) {
        if ([event type] == NSSystemDefined && [event subtype] == 8) {
            int keyCode =  ([event data1] & 0xFFFF0000) >> 16;
            int keyFlags = [event data1] & 0x0000FFFF;
            int keyState = ((keyFlags & 0xFF00) >> 8) == 0xA;
            int keyRepeat = keyFlags & 0x1;
            
            VLCMediaPlayer *mediaPlayer = [[[[NSDocumentController sharedDocumentController] currentDocument] mediaListPlayer] mediaPlayer];
            
            if (keyCode == NX_KEYTYPE_PLAY && keyState == 0 && [mediaPlayer canPause])
                [mediaPlayer pause];
            
            if (keyCode == NX_KEYTYPE_FAST && !_hasJustJumped) {
                if (keyRepeat == 1) {
                    [mediaPlayer shortJumpForward];
                    _hasJustJumped = YES;
                    [self performSelector:@selector(resetJump) withObject:nil afterDelay:0.25];
                }
            }
            
            if (keyCode == NX_KEYTYPE_REWIND && !_hasJustJumped) {
                if (keyRepeat == 1) {
                    [mediaPlayer shortJumpBackward];
                    _hasJustJumped = YES;
                    [self performSelector:@selector(resetJump) withObject:nil afterDelay:0.25];
                }
            }
        }
    }
    [super sendEvent:event];
}

- (void)resetJump
{
    _hasJustJumped = NO;
}

#pragma mark -
#pragma mark IB Action


- (IBAction)reportBug:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://trac.videolan.org"]];
}

- (IBAction)showVideoLANWebsite:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.videolan.org"]];
}

@end

