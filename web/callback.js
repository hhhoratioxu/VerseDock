// Original handoff page. No analytics, cookies, remote scripts, or token exchange.
(() => {
  const query = new URLSearchParams(location.search);
  const state = query.getAll('state');
  const code = query.getAll('code');
  const error = query.getAll('error');
  history.replaceState(null, '', location.pathname);
  const message = document.getElementById('message');
  if (state.length !== 1 || !state[0] ||
      !((code.length === 1 && code[0] && error.length === 0) ||
        (error.length === 1 && code.length === 0))) {
    message.textContent = '回调不完整，请回到 App 重新连接。';
    return;
  }
  const result = new URLSearchParams({ state: state[0] });
  if (code.length) result.set('code', code[0]);
  else result.set('error', error[0]);
  const link = document.getElementById('continue');
  link.href = 'versedock://oauth?' + result.toString();
  link.hidden = false;
  message.textContent = '授权步骤已结束，点击下方按钮返回 App。';
})();
