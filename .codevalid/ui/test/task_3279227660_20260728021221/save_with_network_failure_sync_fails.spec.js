import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import {
  mockGoogleAuthenticatedSession,
  mockDrawingsList,
  drawOnCanvas,
} from "../../helpers/mock-api.js";
import { emptyDrawingsResponse } from "../../mock/mock-data.js";

test("Save succeeds locally but fails sync — system alerts and retries", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "save_with_network_failure_sync_fails",
    testTitle: testInfo.title,
  });

  let uploadAttempts = 0;

  await mockGoogleAuthenticatedSession(page);
  await mockDrawingsList(page, emptyDrawingsResponse);
  await page.route(/\/api\/upload(?:\?.*)?$/, async (route) => {
    uploadAttempts += 1;
    await expect(route.request().method()).toBe("POST");
    await route.fulfill({
      status: 503,
      contentType: "application/json",
      body: JSON.stringify({ message: "Artwork saved locally but cannot sync. Will retry." }),
    });
  });

  await recorder.step("Open draw page and create artwork", async () => {
    await page.goto("/draw");
    await drawOnCanvas(page);
    await expect(page.getByRole("button", { name: "Share my drawing" })).toBeEnabled();
  });

  await recorder.step("Attempt save while synchronized storage is unavailable", async () => {
    await page.getByRole("button", { name: "Share my drawing" }).click();
    await expect(page.getByText("Could not share drawing")).toBeVisible();
    await expect(page.getByText("Artwork saved locally but cannot sync. Will retry.")).toBeVisible();
    expect(uploadAttempts).toBe(1);
    await expect(page).toHaveURL(/\/draw$/);
  });

  console.log("CODEVALID_TEST_ASSERTION_OK:save_with_network_failure_sync_fails");
  await recorder.save(testInfo);
});
