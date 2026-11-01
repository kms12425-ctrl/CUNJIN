/**
 * 寸进 · CUNJIN —— 启动封面
 *
 * 从 pages/Index.ets 原样搬出。约束：
 * 1. 它是根 RelativeContainer 的**最后一个**子节点（最上层），
 *    用来遮住包括弹层在内的一切，调用位置不得移动。
 * 2. 这里的两条 .animation() 是分开写的，且参数与原来逐字一致：
 *    { delay: 0, duration: 500, curve: Curve.ExtremeDeceleration } 然后 { delay: 510, duration: 50 }
 *    —— 故意不使用 animateParam()，因为原来就不是 300ms。
 * 3. opacity 与 Backdrop 共享，所以必须是 @Link。
 */

@Component
export struct StartupCover {
  @Link UI_start_up_cover_continue_opacity: number;
  @Prop DESIGN_color_scheme: string[];

  build() {
    Row() {
    }
    .height("100%")
    .width("100%")
    .backgroundColor($r('app.color.start_window_background'))
    .opacity(this.UI_start_up_cover_continue_opacity)
    .animation({ delay: 0, duration: 500, curve: Curve.ExtremeDeceleration })
    .visibility(this.DESIGN_color_scheme.length == 0 ? Visibility.Visible : Visibility.None)
    .animation({ delay: 510, duration: 50 })
    .onAreaChange(() => {
      setTimeout(() => {
        this.UI_start_up_cover_continue_opacity = 0
      }, 100)
    })
  }
}
