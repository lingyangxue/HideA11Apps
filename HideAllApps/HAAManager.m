- (void)applyHiddenStateToIconView:(id)iconView {
    if (!iconView) return;
    if (![iconView isKindOfClass:[UIView class]]) return;
    UIView *view = (UIView *)iconView;

    // 未启用：完全恢复（可见 + 可交互）
    if (!self.enabled) {
        view.alpha = 1.0;
        view.userInteractionEnabled = YES;
        view.hidden = NO;
        return;
    }

    // 判断该图标是否需要隐藏
    BOOL hide = NO;
    id icon = nil;
    if ([iconView respondsToSelector:@selector(icon)]) {
        icon = [iconView performSelector:@selector(icon)];
    }
    if (icon) {
        NSString *bundleID = nil;
        if ([icon respondsToSelector:@selector(applicationBundleIdentifier)]) {
            bundleID = [icon performSelector:@selector(applicationBundleIdentifier)];
        }
        if (!bundleID && [icon respondsToSelector:@selector(application)]) {
            id app = [icon performSelector:@selector(application)];
            if ([app respondsToSelector:@selector(bundleIdentifier)]) {
                bundleID = [app performSelector:@selector(bundleIdentifier)];
            }
        }
        if (!bundleID && self.hideAll) hide = YES;
        else if (bundleID) hide = [self shouldHideBundleID:bundleID];
    }

    // 关键修复：
    // - 隐藏时：alpha=0 + hidden=YES（不可见，不占位，不响应点击）
    // - 显示时：alpha=1 + hidden=NO + userInteractionEnabled=YES（正常可点）
    if (hide) {
        view.alpha = 0.0;
        view.hidden = YES;
        view.userInteractionEnabled = NO;
    } else {
        view.alpha = 1.0;
        view.hidden = NO;
        view.userInteractionEnabled = YES;
    }
}
