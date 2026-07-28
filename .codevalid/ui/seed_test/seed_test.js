import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../helpers/execution-recorder.js";

test("seed test: app starts and home page is reachable", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "seed-001",
    testTitle: "app starts and home page is reachable",
  });

  await recorder.step("navigate to home", async () => {
    await page.goto("/");
  });

  await recorder.step("assert page title contains Atidraw", async () => {
    await expect(page).toHaveTitle(/Atidraw/i);
  });

  await recorder.step("assert visible page element exists", async () => {
    // The app renders a header or main content area
    const body = page.locator("body");
    await expect(body).toBeVisible();
  });

  await recorder.save(testInfo);
});
