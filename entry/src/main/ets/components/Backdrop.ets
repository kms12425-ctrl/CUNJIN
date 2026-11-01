/**
 * 寸进 · CUNJIN —— 背景遮罩层
 *
 * 从 pages/Index.ets 原样搬出，表达式与动画参数未做任何改动。
 * 约束：它是根 RelativeContainer 的第 2 个子节点，
 * 必须位于背景 Image 之上、内容层（SHELL）之下 —— z 序由声明顺序决定，
 * 因此调用位置不得移动。
 */

import { animateParam } from '../design/JunHaoUi';

@Component
export struct Backdrop {
  // 启动封面淡出后这里要跟着切换到真实配色，所以必须是 @Link 而不是 @Prop
  // （@Prop 只做一次性拷贝，会让启动色永久冻结）。
  @Link UI_start_up_cover_continue_opacity: number;
  @Prop DESIGN_use_backdrop: boolean;
  @Prop DESIGN_color_scheme: string[];

  build() {
    Row() {
    }
    .height("100%")
    .width("100%")
    .backgroundColor(this.UI_start_up_cover_continue_opacity != 0 ? $r('app.color.start_window_background') :
      (this.DESIGN_use_backdrop ? this.DESIGN_color_scheme[0] : this.DESIGN_color_scheme[1]))
    .animation(animateParam(0))
  }
}
