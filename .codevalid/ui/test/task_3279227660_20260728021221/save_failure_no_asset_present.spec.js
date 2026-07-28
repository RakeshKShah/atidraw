import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import {
  mockGoogleAuthenticatedSession,
  mockDrawingsList,
} from "../../helpers/mock-api.js";
import { emptyDrawingsResponse } from "../../mock/mock-data.js";

test("Save fails gracefully when no artwork is present", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "save_failure_no_asset_present",
    testTitle: testInfo.title,
  });

  let uploadCalled = false;

  await mockGoogleAuthenticatedSession(page);
  await mockDrawingsList(page, emptyDrawingsResponse);
  await page.route(/\/api\/upload(?:\?.*)?$/, async (route) => {
    uploadCalled = true;
    await route.fulfill({
      status: 500,
      contentType: "application/json",
      body: JSON.stringify({ message: "Upload should not be called" }),
    });
  });

  await recorder.step("Open draw page with no artwork present", async () => {
    await page.goto("/draw");
    await expect(page.getByRole("button", { name: "Share my drawing" })).toBeDisabled();
  });

  await recorder.step("Verify save cannot proceed without artwork", async () => {
    await expect(page.getByRole("button", { name: "Share my drawing" })).toBeDisabled();
    expect(uploadCalled).toBe(false);
  });

  console.log("CODEVALID_TEST_ASSERTION_OK:save_failure_no_asset_present");
  await recorder.save(testInfo);
});
