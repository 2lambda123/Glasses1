/*****************************************************************************
 * Copyright (C) 2009 the VideoLAN team
 *
 * Authors: Pierre d'Herbemont
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

#import "VLCMediaDocument.h"

@interface VLCMediaDocument () <VLCFullscreenHUDWindowControllerDelegate>
@property (readwrite,retain) VLCMediaPlayer * mediaPlayer;
@end

@implementation VLCMediaDocument
@synthesize mediaPlayer=_mediaPlayer;

- (id)initWithContentsOfURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
	if((self = [super initWithContentsOfURL:absoluteURL ofType:typeName error:outError]))
	{
		_media = [[VLCMedia mediaWithURL:absoluteURL] retain];
	}
	return self;
}

- (void)dealloc
{
	[_fullscreenHUDWindowController release];
	[_media release];
	[_mediaPlayer stop];
	self.mediaPlayer = nil;

	[super dealloc];
}

- (NSString *)windowNibName
{
    return @"MediaDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{
    [super windowControllerDidLoadNib:aController];

	NSRect frame;
	NSWindow * window = [aController window];
	frame = [[window screen] frame];
	frame.size.width = frame.size.width / 3;
	frame.size.height = frame.size.height / 3;
	
	[window setFrame:frame display:NO];
	[window center];

	self.mediaPlayer = [[[VLCMediaPlayer alloc] initWithVideoView:_videoView] autorelease];
	[_videoView setMediaPlayer:_mediaPlayer];
	[_mediaPlayer setMedia:_media];
	[_mediaPlayer play];
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
    if ( outError != NULL ) {
		*outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:NULL];
	}
	return nil;
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
    if ( outError != NULL ) {
		*outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:NULL];
	}
    return YES;
}

#pragma mark -
#pragma mark fullscreenHUDWindowControllerDelegate

- (BOOL)fullscreen
{
    return [_videoView fullscreen];
}

- (void)setFullscreen:(BOOL)fullscreen
{
	[_videoView setFullscreen:fullscreen];
}

#pragma mark -
#pragma mark IBAction

- (IBAction)togglePlayPause:(id)sender
{
	if([_mediaPlayer isPlaying])
		[_mediaPlayer pause];
	else
		[_mediaPlayer play];
}

- (IBAction)toggleFullscreen:(id)sender
{
	[self setFullscreen:![self fullscreen]];
}
@end
