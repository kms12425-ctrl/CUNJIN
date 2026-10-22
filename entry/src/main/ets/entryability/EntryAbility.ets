import { AbilityConstant, UIAbility, Want, Configuration } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { TaskRepository } from '../repository/TaskRepository';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    AppStorage.setOrCreate('currentColorMode', this.context.config.colorMode);
    AppStorage.setOrCreate('currentDirection', this.context.config.direction);
    // save current color mode
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onCreate');

    // 存储初始化：用 UIAbilityContext 显式初始化。
    // 替代旧版在模块作用域调用已废弃的 getContext(this) —— 那个写法在页面上下文之外
    // 可能拿到无效 context，导致 KVStore 整个进程都不可用、写入被静默丢弃。
    // 这里不 await：页面会 await 同一个 Promise，初始化失败会记录并允许下次重试。
    TaskRepository.init(this.context).catch((error: Error) => {
      hilog.error(0x0000, 'testTag', 'TaskRepository init failed: %{public}s', error.message);
    });
  }

  onDestroy(): void {
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(0x0000, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err) ?? '');
        return;
      }
      hilog.info(0x0000, 'testTag', 'Succeeded in loading the content.');

      let windowClass: window.Window = windowStage.getMainWindowSync(); // 获取应用主窗口
      // 1. 设置窗口全屏
      let isLayoutFullScreen = true;
      windowClass.setWindowLayoutFullScreen(isLayoutFullScreen)
        .then(() => {
          console.info('Succeeded in setting the window layout to full-screen mode.');
        })
        .catch((err: BusinessError) => {
          console.error('Failed to set the window layout to full-screen mode. Cause:' + JSON.stringify(err));
        });
      // 2. 获取布局避让遮挡的区域
      let type = window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR; // 以导航条避让为例
      let avoidArea = windowClass.getWindowAvoidArea(type);
      let bottomRectHeight = avoidArea.bottomRect.height; // 获取到导航条区域的高度
      AppStorage.setOrCreate('bottomRectHeight', bottomRectHeight);

    });
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    // EntryAbility.ts入口文件中获取环境变化，修改状态
    AppStorage.setOrCreate('currentColorMode', newConfig.colorMode);
    AppStorage.setOrCreate('currentDirection', newConfig.direction);

  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
