import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import { mockGoogleAuthenticatedSession } from "../../helpers/mock-api.js";

function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function appOriginRegex(pathname) {
  return new RegExp(`^https?:\\/\\/[^/]+${escapeRegex(pathname)}(?:\\?.*)?$`);
}

async function drawStroke(page, points) {
  const canvas = page.locator("canvas");
  const box = await canvas.boundingBox();
  if (!box) throw new Error("Canvas bounding box unavailable");

  await page.mouse.move(box.x + points[0][0], box.y + points[0][1]);
  await page.mouse.down();
  for (const [x, y] of points.slice(1)) {
    await page.mouse.move(box.x + x, box.y + y, { steps: 4 });
  }
  await page.mouse.up();
}

test("No JavaScript errors occur during user interaction with canvas", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "no_js_errors_during_drawing",
    testTitle: testInfo.title,
  });

  await mockGoogleAuthenticatedSession(page);

  const pageErrors = [];
  const consoleErrors = [];
  page.on("pageerror", (error) => pageErrors.push(error.message));
  page.on("console", (msg) => {
    if (msg.type() === "error") consoleErrors.push(msg.text());
  });

  let uploadCount = 0;
  await page.route(appOriginRegex("/api/upload"), async (route) => {
    uploadCount += 1;
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({ ok: true, pathname: `drawings/run-${uploadCount}.jpg` }),
    });
  });

  await recorder.step("Open draw page", async () => {
    await page.goto("/draw");
    await expect(page.locator("canvas")).toBeVisible();
  });

  await recorder.step("Rapidly draw, clear, redraw, and share multiple times", async () => {
    for (let i = 0; i < 3; i += 1) {
      await drawStroke(page, [[40, 50 + i * 20], [100, 90 + i * 20], [180, 120 + i * 20], [260, 150 + i * 20]]);
      await expect(page.getByRole("button", { name: /Share my drawing|Sharing... \(can take a minute\)/ })).toBeEnabled();
      await page.getByRole("button", { name: "Clear" }).click();
      await expect(page.getByRole("button", { name: "Share my drawing" })).toBeDisabled();
      await drawStroke(page, [[80, 60 + i * 15], [120, 110 + i * 15], [170, 160 + i * 15]]);
      await page.getByRole("button", { name: "Share my drawing" }).click();
      await page.waitForURL("/");
      await page.goto("/draw");
      await expect(page.locator("canvas")).toBeVisible();
    }
  });

  await recorder.step("Assert no console or page errors were emitted", async () => {
    expect(uploadCount).toBe(3);
    expect(pageErrors).toEqual([]);
    expect(consoleErrors).toEqual([]);
  });

  console.log("CODEVALID_TEST_ASSERTION_OK:no_js_errors_during_drawing");
  await recorder.save(testInfo);
});
