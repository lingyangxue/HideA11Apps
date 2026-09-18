- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"重启桌面"
                                                                   message:@"确定要重启 SpringBoard 吗？"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消"
                                              style:UIAlertActionStyleCancel
                                            handler:^(UIAlertAction *a) {
        [self.navigationController popViewControllerAnimated:YES];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"重启"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *a) {
        [self doRespring];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)doRespring {
    // 方式 1：直接杀 SpringBoard 进程（最可靠）
    Class sbcClass = NSClassFromString(@"FBSystemService");
    if (sbcClass) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        id shared = nil;
        if ([sbcClass respondsToSelector:@selector(sharedInstance)]) {
            shared = [sbcClass performSelector:@selector(sharedInstance)];
        }
        if (shared && [shared respondsToSelector:@selector(exitImmediately)]) {
            [shared performSelector:@selector(exitImmediately)];
            return;
        }
#pragma clang diagnostic pop
    }

    // 方式 2：用 kill() 系统调用
    // SpringBoard 的 PID 一般是 1 或者通过 sysctl 找
    kill(1, SIGKILL);

    // 方式 3：posix_spawn killall 兜底
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        pid_t pid;
        const char *paths[] = {
            "/var/jb/usr/bin/killall",
            "/usr/bin/killall",
            "/var/jb/usr/bin/sbreload",
            "/usr/bin/sbreload",
            NULL
        };
        for (int i = 0; paths[i] != NULL; i++) {
            const char *args[] = { paths[i], "-9", "SpringBoard", NULL };
            posix_spawn(&pid, paths[i], NULL, NULL, (char * const *)args, NULL);
        }
    });
}
