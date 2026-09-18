- (void)reload {
    NSUserDefaults *d = [self defaults];
    self.enabled          = [d boolForKey:@"enabled"];
    self.gestureType      = [d integerForKey:@"gestureType"];
    self.shakeEnabled     = [d boolForKey:@"shakeEnabled"];
    self.leftDownEnabled  = [d boolForKey:@"leftDownEnabled"];
    self.hideAll          = [d boolForKey:@"hideAll"];
    NSArray *arr          = [d arrayForKey:@"hiddenBundleIDs"] ?: @[];
    self.hiddenBundleIDs  = [NSSet setWithArray:arr];

    if (self.hideAll) [self startRefreshTimer];
    else [self stopRefreshTimer];
}
