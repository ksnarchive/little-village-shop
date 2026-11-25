// Shared real UI action for checks whose subject begins in the shop.
exports.skipTrain = async (page, tap) => {
  const [width, height] = await page.locator('#canvas').evaluate(c => [c.width, c.height]);
  await tap(width - 70, 30);
  await tap(width / 2, height / 2 + 44);
  await page.waitForFunction(() => !document.body.classList.contains('frontend'), null, {timeout: 10000});
  await page.waitForTimeout(250);
};
