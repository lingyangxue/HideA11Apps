PSSpecifier *group3 = [PSSpecifier groupSpecifierWithName:@"摇一摇（只隐藏，独立开关）"];
        [group3 setProperty:@"摇一摇手机只隐藏，恢复请用上面的状态栏双击手势" forKey:@"footerText"];
        [specs addObject:group3];

        PSSpecifier *shake = [PSSpecifier preferenceSpecifierNamed:@"启用摇一摇隐藏" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
        [shake setProperty:@"shakeEnabled" forKey:@"key"];
        [shake setProperty:@NO forKey:@"default"];
        [specs addObject:shake];
