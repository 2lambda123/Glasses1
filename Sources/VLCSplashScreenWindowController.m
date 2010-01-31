/*****************************************************************************
 * Copyright (C) 2009 the VideoLAN team
 *
 * Authors: Pierre d'Herbemont
 *          Felix Paul Kühne
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

#import "VLCSplashScreenWindowController.h"
#import "VLCDocumentController.h"

#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_5
@interface VLCSplashScreenWindowController () <NSWindowDelegate>
@end
#endif

@interface VLCSplashScreenWindowController ()
@property (assign, readwrite) BOOL hasSelection;
@end


@implementation VLCSplashScreenWindowController
@synthesize hasSelection=_hasSelection;

- (NSArray *)availableMediaDiscoverer
{
    return [VLCMediaDiscoverer availableMediaDiscoverer];
}

- (NSString *)windowNibName
{
    return @"SplashScreenWindow";
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    NSWindow *window = [self window];

    [window center];
    [window setDelegate:self];
    NSAssert(_mediaDiscoverCollection, @"There is no collectionView");
    NSAssert(_unfinishedItemsCollection, @"There is no collectionView");
    [_unfinishedItemsCollection registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
}

- (void)windowWillClose:(NSNotification *)notification
{
    [_unfinishedItemsCollection setDelegate:nil];
    [_mediaDiscoverCollection setDelegate:nil];
    [[VLCDocumentController sharedDocumentController] closeSplashScreen];
}

/**
 * This methods is being used by the bindings of the services view.
 */
- (VLCDocumentController *)documentController
{
    return [VLCDocumentController sharedDocumentController];
}

- (void)collectionView:(NSCollectionView *)collectionView doubleClickedOnItemAtIndex:(NSUInteger)index
{
    VLCDocumentController *controller = [VLCDocumentController sharedDocumentController];
    if (collectionView == _mediaDiscoverCollection) {
#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_5
        id object = [[_mediaDiscoverCollection itemAtIndex:index] representedObject];
#else
        id object = [_mediaDiscovererArrayController objectAtIndex:index];
#endif
        [controller makeDocumentWithObject:object];
    }
    else {
#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_5
        id representedObject = [[collectionView itemAtIndex:index] representedObject];
#else
        id representedObject = [[[NSUserDefaults standardUserDefaults] arrayForKey:kUnfinishedMoviesAsArray] objectAtIndex:index];
#endif
        NSURL *url = [NSURL URLWithString:[representedObject valueForKey:@"url"]];
        double position = [[representedObject valueForKey:@"lastPosition"] doubleValue];
        [controller makeDocumentWithURL:url andStartingPosition:position];
    }
    [[self window] close];
}

- (void)collectionView:(NSCollectionView *)collectionView willChangeSelectionIndexes:(NSIndexSet *)set
{
    if (collectionView == _mediaDiscoverCollection)
        [_unfinishedItemsCollection setSelectionIndexes:[NSIndexSet indexSet]];
    else
        [_mediaDiscoverCollection setSelectionIndexes:[NSIndexSet indexSet]];

    self.hasSelection = ([[_unfinishedItemsCollection selectionIndexes] count] > 0) || [[_mediaDiscoverCollection selectionIndexes] count] > 0 || [set count] > 0;
}

- (NSDragOperation)collectionView:(NSCollectionView *)collectionView validateDrop:(id < NSDraggingInfo >)draggingInfo proposedIndex:(NSInteger *)proposedDropIndex dropOperation:(NSCollectionViewDropOperation *)proposedDropOperation
{
    if (collectionView == _mediaDiscoverCollection)
        return NSDragOperationNone;
    return NSDragOperationGeneric;

}

- (BOOL)collectionView:(NSCollectionView *)collectionView acceptDrop:(id < NSDraggingInfo >)draggingInfo index:(NSInteger)index dropOperation:(NSCollectionViewDropOperation)dropOperation
{
    NSAssert(collectionView == _unfinishedItemsCollection, @"Not the right collectionView");
    NSPasteboard *pboard = [draggingInfo draggingPasteboard];
    NSArray *array = [pboard propertyListForType:NSFilenamesPboardType];
    NSAssert([array count] > 0, @"There should be at least one item dropped");

    VLCMedia *media = [VLCMedia mediaWithPath:[array objectAtIndex:0]];

    // FIXME - This is blocking and we don't have any fallback
    [media lengthWaitUntilDate:[NSDate dateWithTimeIntervalSinceNow:2]];

    [[self documentController] media:media wasClosedAtPosition:0];
    return YES;
}

- (IBAction)openSelection:(id)sender
{
    NSAssert(_mediaDiscoverCollection, @"Should be binded");
    NSIndexSet *discoverers = [_mediaDiscoverCollection selectionIndexes];
    NSIndexSet *unfinished = [_unfinishedItemsCollection selectionIndexes];
    if ([discoverers count] > 0)
        [self collectionView:_mediaDiscoverCollection doubleClickedOnItemAtIndex:[discoverers firstIndex]];
    else if ([unfinished count] > 0)
         [self collectionView:_unfinishedItemsCollection doubleClickedOnItemAtIndex:[unfinished firstIndex]];
    else
         VLCAssertNotReached(@"We shouldn't have received this action in the first place");
}
@end
