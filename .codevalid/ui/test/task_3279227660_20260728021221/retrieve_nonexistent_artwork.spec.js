import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import {
  mockGoogleAuthenticatedSession,
  mockDrawingsList,
} from "../../helpers/mock-api.js";
import { emptyDrawingsResponse } from "../../mock/mock-data.js";

test("User attempts to retrieve non-existent artwork — system handles gracefully", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "retrieve_nonexistent_artwork",
    testTitle: testInfo.title,
  });

  await mockGoogleAuthenticatedSession(page);
  await mockDrawingsList(page, emptyDrawingsResponse);

  await recorder.step("Open asset library with no matching artwork", async () => {
    await page.goto("/");
    await expect(page.getByRole("img")).toHaveCount(0);
  });

  await recorder.step("Verify UI remains stable without broken artwork state", async () => {
    await expect(page.locator("body")).toBeVisible();
    await expect(page.getByText("Google User")).toHaveCount(0);
  });

  console.log("CODEVALID_TEST_ASSERTION_OK:retrieve_nonexistent_artwork");
  await recorder.save(testInfo);
});
